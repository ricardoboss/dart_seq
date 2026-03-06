import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

class _MockSeqClient implements SeqClient {
  List<Iterable<SeqEvent>> sentBatches = [];
  String? _minimumLevelAccepted;
  Exception? throwOnSend;

  /// When set, sendEvents returns these results instead of all-success.
  Iterable<SeqEventResult>? resultsToReturn;

  @override
  String? get minimumLevelAccepted => _minimumLevelAccepted;

  set minimumLevelAccepted(String? value) => _minimumLevelAccepted = value;

  @override
  Future<Iterable<SeqEventResult>> sendEvents(Iterable<SeqEvent> events) async {
    if (throwOnSend != null) {
      throw throwOnSend!;
    }

    sentBatches.add(events);

    if (resultsToReturn != null) {
      return resultsToReturn!;
    }

    return events.map(SeqEventResult.success);
  }
}

class _MockSeqCache implements SeqCache {
  final List<SeqEvent> _events = [];

  @override
  int get count => _events.length;

  @override
  Future<void> record(SeqEvent event) async {
    _events.add(event);
  }

  @override
  Stream<SeqEvent> peek(int count) async* {
    final max = count.clamp(0, _events.length);
    for (var i = 0; i < max; i++) {
      yield _events[i];
    }
  }

  @override
  Future<void> remove(int count) async {
    final max = count.clamp(0, _events.length);
    _events.removeRange(0, max);
  }
}

class _NonRetryableException extends SeqClientException {
  _NonRetryableException(super.message);

  @override
  bool get isRetryable => false;
}

void main() {
  group('SeqLogger', () {
    late _MockSeqClient client;
    late _MockSeqCache cache;

    setUp(() {
      client = _MockSeqClient();
      cache = _MockSeqCache();
      SeqLogger.onDiagnosticLog = null;
    });

    test('happy path: log -> auto-flush -> client receives events', () async {
      client.minimumLevelAccepted = 'Information';

      final logger = SeqLogger(
        client: client,
        cache: cache,
        backlogLimit: 1,
        globalContext: {'app': 'test'},
      );

      await logger.log(SeqLogLevel.information, 'test');

      expect(client.sentBatches, hasLength(1));

      final sentEvent = client.sentBatches.first.first;
      expect(sentEvent.context, isNotNull);
      expect(sentEvent.context!['app'], 'test');
      expect(logger.minimumLogLevel, 'Information');
    });

    group('flush', () {
      test('keeps events in cache when sendEvents throws', () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));
        await logger.flush();

        expect(cache.count, 2);
      });

      test(
        'calls onFlushError with synthetic results on total failure',
        () async {
          final sendError = Exception('bad request');
          client.throwOnSend = sendError;

          Iterable<SeqEventResult>? capturedResults;

          final logger = SeqLogger(
            client: client,
            cache: cache,
            backlogLimit: 10,
            autoFlush: false,
            onFlushError: (results, error) async {
              capturedResults = results;
              return [];
            },
          );

          await logger.send(SeqEvent.info('one'));
          await logger.flush();

          expect(capturedResults, isNotNull);
          expect(capturedResults, hasLength(1));
          expect(capturedResults!.first.isSuccess, isFalse);
          expect(capturedResults!.first.error, sendError);
        },
      );

      test(
        'calls onFlushError with per-event results on partial failure',
        () async {
          final event1 = SeqEvent.info('good');
          final event2 = SeqEvent.info('bad');

          client.resultsToReturn = [
            SeqEventResult.success(event1),
            SeqEventResult.failure(event2, Exception('malformed')),
          ];

          Iterable<SeqEventResult>? capturedResults;

          final logger = SeqLogger(
            client: client,
            cache: cache,
            backlogLimit: 10,
            autoFlush: false,
            onFlushError: (results, error) async {
              capturedResults = results;
              return [];
            },
          );

          await cache.record(event1);
          await cache.record(event2);
          await logger.flush();

          final resultsList = capturedResults!.toList();
          expect(resultsList, hasLength(2));
          expect(resultsList[0].isSuccess, isTrue);
          expect(resultsList[1].isSuccess, isFalse);
        },
      );

      test('partial failure drops permanent, re-queues transient', () async {
        final event1 = SeqEvent.info('good');
        final event2 = SeqEvent.info('bad-permanent');
        final event3 = SeqEvent.info('bad-transient');

        client.resultsToReturn = [
          SeqEventResult.success(event1),
          SeqEventResult.failure(
            event2,
            Exception('malformed'),
            isPermanent: true,
          ),
          SeqEventResult.failure(event3, Exception('network error')),
        ];

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await cache.record(event1);
        await cache.record(event2);
        await cache.record(event3);
        await logger.flush();

        expect(
          cache.count,
          1,
          reason: 'Permanent dropped, transient re-queued',
        );
      });

      test('logs diagnostic for permanently dropped events', () async {
        final event1 = SeqEvent.info('good');
        final event2 = SeqEvent.info('bad-trace-id');

        client.resultsToReturn = [
          SeqEventResult.success(event1),
          SeqEventResult.failure(
            event2,
            Exception('invalid @tr'),
            isPermanent: true,
          ),
        ];

        final diagnosticEvents = <SeqEvent>[];
        SeqLogger.onDiagnosticLog = diagnosticEvents.add;

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await cache.record(event1);
        await cache.record(event2);
        await logger.flush();

        final warnings = diagnosticEvents
            .where((e) => e.level == 'warning')
            .toList();
        expect(warnings, hasLength(1));
        expect(warnings.first.context!['Message'], 'bad-trace-id');
      });

      test(
        'non-retryable exception halves batch size across flushes',
        () async {
          client.throwOnSend = _NonRetryableException('payload too large');

          final logger = SeqLogger(
            client: client,
            cache: cache,
            backlogLimit: 10,
            autoFlush: false,
          );

          for (var i = 0; i < 4; i++) {
            await logger.send(SeqEvent.info('event-$i'));
          }

          // First flush: tries all 4, fails, halves to 2
          await logger.flush();
          expect(cache.count, 4);

          // Second flush: tries first 2, fails, halves to 1
          await logger.flush();
          expect(cache.count, 4);

          // Third flush: tries 1 event, fails, drops it
          await logger.flush();
          expect(cache.count, 3, reason: 'Single non-retryable event dropped');
        },
      );

      test('batch size resets after successful smaller flush', () async {
        client.throwOnSend = _NonRetryableException('payload too large');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 4,
          autoFlush: false,
        );

        for (var i = 0; i < 4; i++) {
          await logger.send(SeqEvent.info('event-$i'));
        }

        // First flush: tries 4, fails -> halves to 2
        await logger.flush();

        // Now make sends succeed
        client.throwOnSend = null;

        // Second flush: tries 2, succeeds -> resets to 4
        await logger.flush();
        expect(cache.count, 2);

        // Third flush: remaining 2
        await logger.flush();
        expect(cache.count, 0);
      });

      test('retryable exception keeps events in cache', () async {
        client.throwOnSend = SeqClientException('network error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.flush();

        expect(cache.count, 1);
      });
    });

    group('throwOnError', () {
      test('swallows flush errors when false', () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(client: client, cache: cache, backlogLimit: 1);

        // Should not throw
        await logger.send(SeqEvent.info('test'));
      });

      test('propagates flush errors when true', () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 1,
          throwOnError: true,
        );

        await expectLater(
          logger.send(SeqEvent.info('test')),
          throwsA(isA<Exception>()),
        );
      });

      test('does not rethrow when onFlushError is set', () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 1,
          throwOnError: true,
          onFlushError: (results, error) async => [],
        );

        // Should not throw because onFlushError handles it
        await logger.send(SeqEvent.info('test'));
      });
    });

    group('log', () {
      test('passes OTEL properties through', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        final spanStart = DateTime.utc(2024, 6);
        await logger.log(
          SeqLogLevel.information,
          'test',
          traceId: 'trace1',
          spanId: 'span1',
          parentSpanId: 'parent1',
          spanStart: spanStart,
          scope: 'MyScope',
          resourceAttributes: {'key': 'val'},
          spanKind: 'Server',
        );

        final event = await cache.peek(1).first;
        expect(event.traceId, 'trace1');
        expect(event.spanId, 'span1');
        expect(event.parentSpanId, 'parent1');
        expect(event.spanStart, spanStart);
        expect(event.scope, 'MyScope');
        expect(event.resourceAttributes, {'key': 'val'});
        expect(event.spanKind, 'Server');
      });

      test('uses named exception parameter', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        final exception = Exception('fail');
        await logger.log(SeqLogLevel.error, 'oops', exception: exception);

        final event = await cache.peek(1).first;
        expect(event.exception, exception);
      });

      test('uses named context parameter', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        await logger.log(
          SeqLogLevel.information,
          'test {Key}',
          context: {'Key': 'value'},
        );

        final event = await cache.peek(1).first;
        expect(event.context!['Key'], 'value');
      });
    });
  });
}
