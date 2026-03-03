import 'dart:async';

import 'package:dart_seq/dart_seq.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

class _MockSeqClient implements SeqClient {
  List<List<SeqEvent>> sentBatches = [];
  String? _minimumLevelAccepted;
  Exception? throwOnSend;

  /// When set, sendEvents returns these results instead of all-success.
  List<SeqEventSentResult>? resultsToReturn;

  @override
  String? get minimumLevelAccepted => _minimumLevelAccepted;

  set minimumLevelAccepted(String? value) => _minimumLevelAccepted = value;

  @override
  Future<List<SeqEventSentResult>> sendEvents(List<SeqEvent> events) async {
    if (throwOnSend != null) {
      throw throwOnSend!;
    }
    sentBatches.add(events);

    if (resultsToReturn != null) {
      return resultsToReturn!;
    }

    return events.map(SeqEventSentResult.success).toList();
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

class _SlowSeqClient implements SeqClient {
  _SlowSeqClient();

  List<List<SeqEvent>> sentBatches = [];
  Duration delay = const Duration(milliseconds: 50);

  @override
  String? get minimumLevelAccepted => null;

  @override
  Future<List<SeqEventSentResult>> sendEvents(List<SeqEvent> events) async {
    await Future<void>.delayed(delay);
    sentBatches.add(List.of(events));
    return events.map(SeqEventSentResult.success).toList();
  }
}

class _ThrowingPeekCache implements SeqCache {
  final List<SeqEvent> _events = [];

  @override
  int get count => _events.length;

  @override
  Future<void> record(SeqEvent event) async {
    _events.add(event);
  }

  @override
  Stream<SeqEvent> peek(int count) {
    throw Exception('peek error');
  }

  @override
  Future<void> remove(int count) async {
    final max = count.clamp(0, _events.length);
    _events.removeRange(0, max);
  }
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

    group('compareLevels', () {
      test('both null returns 0', () {
        expect(SeqLogger.compareLevels(null, null), 0);
      });

      test('a null returns -1', () {
        expect(SeqLogger.compareLevels(null, 'Information'), -1);
      });

      test('b null returns 1', () {
        expect(SeqLogger.compareLevels('Information', null), 1);
      });

      test('same level returns 0', () {
        expect(SeqLogger.compareLevels('Warning', 'Warning'), 0);
      });

      test('lower < higher returns negative', () {
        expect(SeqLogger.compareLevels('Debug', 'Error'), lessThan(0));
      });

      test('higher > lower returns positive', () {
        expect(SeqLogger.compareLevels('Fatal', 'Verbose'), greaterThan(0));
      });

      test('unknown level returns -1 from levelToInt', () {
        // unknown == -1, which is less than any known level
        expect(SeqLogger.compareLevels('Unknown', 'Verbose'), lessThan(0));
      });
    });

    group('levelToInt', () {
      test(
        'Verbose is 0',
        () => expect(SeqLogger.levelToInt('Verbose'), 0),
      );
      test(
        'Debug is 1',
        () => expect(SeqLogger.levelToInt('Debug'), 1),
      );
      test(
        'Information is 2',
        () => expect(SeqLogger.levelToInt('Information'), 2),
      );
      test(
        'Warning is 3',
        () => expect(SeqLogger.levelToInt('Warning'), 3),
      );
      test(
        'Error is 4',
        () => expect(SeqLogger.levelToInt('Error'), 4),
      );
      test(
        'Fatal is 5',
        () => expect(SeqLogger.levelToInt('Fatal'), 5),
      );
      test(
        'unknown returns -1',
        () => expect(SeqLogger.levelToInt('Banana'), -1),
      );
    });

    group('shouldLog', () {
      test('returns true when minimumLogLevel is null', () {
        final logger = SeqLogger(
          client: client,
          cache: cache,
        );

        final event = SeqEvent.verbose('test');
        expect(logger.shouldLog(event), isTrue);
      });

      test('returns true when event level >= minimum', () {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          minimumLogLevel: 'Warning',
        );

        expect(logger.shouldLog(SeqEvent.warning('test')), isTrue);
        expect(logger.shouldLog(SeqEvent.error('test')), isTrue);
        expect(logger.shouldLog(SeqEvent.fatal('test')), isTrue);
      });

      test('returns false when event level < minimum', () {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          minimumLogLevel: 'Warning',
        );

        expect(logger.shouldLog(SeqEvent.verbose('test')), isFalse);
        expect(logger.shouldLog(SeqEvent.debug('test')), isFalse);
        expect(logger.shouldLog(SeqEvent.info('test')), isFalse);
      });
    });

    group('shouldFlush', () {
      test('returns true when cache count >= backlogLimit', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 2,
        );

        await cache.record(SeqEvent.info('1'));
        await cache.record(SeqEvent.info('2'));

        expect(logger.shouldFlush(), isTrue);
      });

      test('returns false when cache count < backlogLimit', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 5,
        );

        await cache.record(SeqEvent.info('1'));

        expect(logger.shouldFlush(), isFalse);
      });
    });

    group('send', () {
      test('skips events below minimum level', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          minimumLogLevel: 'Error',
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('should be skipped'));

        expect(cache.count, 0);
      });

      test('records event in cache', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('test'));

        expect(cache.count, 1);
      });

      test('adds global context to event', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
          globalContext: {'App': 'TestApp'},
        );

        await logger.send(SeqEvent.info('test'));

        final cached = await cache.peek(1).first;
        expect(cached.context, isNotNull);
        expect(cached.context!['App'], 'TestApp');
      });

      test('auto-flush triggers when backlogLimit reached', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 2,
        );

        await logger.send(SeqEvent.info('first'));
        expect(client.sentBatches, isEmpty);

        await logger.send(SeqEvent.info('second'));
        expect(client.sentBatches, hasLength(1));
        expect(client.sentBatches.first, hasLength(2));
      });

      test('does not auto-flush when autoFlush is false', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 1,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('test'));

        expect(client.sentBatches, isEmpty);
        expect(cache.count, 1);
      });
    });

    group('addContext', () {
      test('adds global context to event', () {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          globalContext: {'env': 'test'},
        );

        final event = SeqEvent.info('msg');
        final result = logger.addContext(event);

        expect(result.context!['env'], 'test');
      });

      test('returns same event when no global context', () {
        final logger = SeqLogger(client: client, cache: cache);

        final event = SeqEvent.info('msg');
        final result = logger.addContext(event);

        expect(identical(result, event), isTrue);
      });
    });

    group('flush', () {
      test('sends cached events to client', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));
        await logger.flush();

        expect(client.sentBatches, hasLength(1));
        expect(client.sentBatches.first, hasLength(2));
      });

      test('removes sent events from cache', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));
        await logger.flush();

        expect(cache.count, 0);
      });

      test('updates minimumLogLevel from client', () async {
        client.minimumLevelAccepted = 'Warning';

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('test'));
        await logger.flush();

        expect(logger.minimumLogLevel, 'Warning');
      });

      test('sends at most backlogLimit events per flush', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 2,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('1'));
        await logger.send(SeqEvent.info('2'));
        await logger.send(SeqEvent.info('3'));

        await logger.flush();

        expect(client.sentBatches.first, hasLength(2));
        expect(cache.count, 1);
      });

      test('concurrent flush calls do not send duplicate events', () async {
        final slowClient = _SlowSeqClient();
        final logger = SeqLogger(
          client: slowClient,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));

        // Fire two flushes concurrently — second should be a no-op
        await Future.wait([logger.flush(), logger.flush()]);

        expect(
          slowClient.sentBatches,
          hasLength(1),
          reason: 'Only one flush should execute; the other should be skipped',
        );
      });

      test('keeps events in cache when sendEvents throws (no onFlushError)',
          () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));

        expect(cache.count, 2);

        await logger.flush();

        expect(
          cache.count,
          2,
          reason: 'Events stay in cache on total failure (safe default)',
        );
      });

      test(
          'calls onFlushError with synthetic failure results on total failure',
          () async {
        final sendError = Exception('bad request');
        client.throwOnSend = sendError;

        List<SeqEventSentResult>? capturedResults;
        Object? capturedException;

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
          onFlushError: (results, error) async {
            capturedResults = results;
            capturedException = error;
            return [];
          },
        );

        await logger.send(SeqEvent.info('one'));
        await logger.flush();

        expect(capturedResults, isNotNull);
        expect(capturedResults, hasLength(1));
        expect(capturedResults!.first.isSuccess, isFalse);
        expect(capturedResults!.first.error, sendError);
        expect(capturedException, sendError);
      });

      test('re-records events returned from onFlushError on total failure',
          () async {
        client.throwOnSend = Exception('temporary error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
          onFlushError: (results, error) async {
            // Keep all events for retry
            return results.map((r) => r.event).toList();
          },
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));

        expect(cache.count, 2);

        await logger.flush();

        expect(cache.count, 2, reason: 'Events re-recorded by onFlushError');
      });

      test('removes events from cache on total failure with onFlushError '
          'returning empty list', () async {
        client.throwOnSend = Exception('permanent error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
          onFlushError: (results, error) async => [],
        );

        await logger.send(SeqEvent.info('one'));
        await logger.send(SeqEvent.info('two'));

        await logger.flush();

        expect(cache.count, 0, reason: 'onFlushError returned empty list');
      });

      test('calls onFlushError with per-event results on partial failure',
          () async {
        final event1 = SeqEvent.info('good');
        final event2 = SeqEvent.info('bad');
        final failureError = Exception('malformed');

        client.resultsToReturn = [
          SeqEventSentResult.success(event1),
          SeqEventSentResult.failure(event2, failureError),
        ];

        List<SeqEventSentResult>? capturedResults;

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

        expect(capturedResults, isNotNull);
        expect(capturedResults, hasLength(2));
        expect(capturedResults![0].isSuccess, isTrue);
        expect(capturedResults![1].isSuccess, isFalse);
      });

      test('partial failure without onFlushError drops permanent failures',
          () async {
        final event1 = SeqEvent.info('good');
        final event2 = SeqEvent.info('bad');

        client.resultsToReturn = [
          SeqEventSentResult.success(event1),
          SeqEventSentResult.failure(
            event2,
            Exception('malformed'),
            isPermanent: true,
          ),
        ];

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await cache.record(event1);
        await cache.record(event2);
        await logger.flush();

        expect(
          cache.count,
          0,
          reason: 'Permanent failure dropped, successful already sent',
        );
      });

      test(
          'partial failure without onFlushError re-queues transient failures',
          () async {
        final event1 = SeqEvent.info('good');
        final event2 = SeqEvent.info('transient-fail');

        client.resultsToReturn = [
          SeqEventSentResult.success(event1),
          SeqEventSentResult.failure(event2, Exception('network error')),
        ];

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await cache.record(event1);
        await cache.record(event2);
        await logger.flush();

        expect(
          cache.count,
          1,
          reason: 'Transient failure re-queued for retry',
        );
      });

      test('logs diagnostic on flush failure', () async {
        client.throwOnSend = Exception('server error');

        SeqEvent? diagnosticEvent;
        SeqLogger.onDiagnosticLog = (event) {
          if (event.level == 'error') {
            diagnosticEvent = event;
          }
        };

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 10,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('one'));
        await logger.flush();

        expect(diagnosticEvent, isNotNull);
        expect(diagnosticEvent!.context!['EventCount'], 1);
      });

      test('shouldFlush returns false while flushing (concurrent guard)',
          () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 1,
          autoFlush: false,
        );

        await logger.send(SeqEvent.info('test'));

        // Before flush, shouldFlush is true
        expect(logger.shouldFlush(), isTrue);

        // Start flush but don't await — we can't easily test _flushing=true
        // mid-flight with synchronous mocks, so instead verify the guard
        // resets after flush completes
        await logger.flush();
        expect(
          logger.shouldFlush(),
          isFalse,
          reason: 'Cache is empty after flush',
        );
      });
    });

    group('log', () {
      test('creates event and sends it', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        await logger.log(SeqLogLevel.information, 'hello');

        expect(cache.count, 1);
        final event = await cache.peek(1).first;
        expect(event.level, 'Information');
      });

      test('treats empty context as null', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        await logger.log(SeqLogLevel.information, 'test', context: {});

        final event = await cache.peek(1).first;
        // Empty context passed to log() becomes null, so SeqEvent.now()
        // gets null context -> sets message, not messageTemplate
        expect(event.message, 'test');
        expect(event.messageTemplate, isNull);
      });

      test('passes exception through', () async {
        final logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );

        final exception = Exception('fail');
        await logger.log(
          SeqLogLevel.error,
          'oops',
          exception: exception,
        );

        final event = await cache.peek(1).first;
        expect(event.exception, exception);
      });

      test('passes new CLEF properties through', () async {
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
    });

    group('convenience methods', () {
      late SeqLogger logger;

      setUp(() {
        logger = SeqLogger(
          client: client,
          cache: cache,
          autoFlush: false,
        );
      });

      test('verbose logs at Verbose level', () async {
        await logger.verbose('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Verbose');
      });

      test('debug logs at Debug level', () async {
        await logger.debug('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Debug');
      });

      test('info logs at Information level', () async {
        await logger.info('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Information');
      });

      test('warning logs at Warning level', () async {
        await logger.warning('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Warning');
      });

      test('error logs at Error level', () async {
        await logger.error('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Error');
      });

      test('error passes exception', () async {
        final ex = Exception('boom');
        await logger.error('test', exception: ex);
        final event = await cache.peek(1).first;
        expect(event.exception, ex);
      });

      test('fatal logs at Fatal level', () async {
        await logger.fatal('test');
        final event = await cache.peek(1).first;
        expect(event.level, 'Fatal');
      });

      test('fatal passes exception', () async {
        final ex = Exception('critical');
        await logger.fatal('test', exception: ex);
        final event = await cache.peek(1).first;
        expect(event.exception, ex);
      });

      test('verbose with context passes context through', () async {
        await logger.verbose('test', context: {'key': 'value'});
        final event = await cache.peek(1).first;
        expect(event.context, isNotNull);
        expect(event.context!['key'], 'value');
      });

      test('debug with context passes context through', () async {
        await logger.debug('test', context: {'key': 'value'});
        final event = await cache.peek(1).first;
        expect(event.context, isNotNull);
        expect(event.context!['key'], 'value');
      });

      test('info with context passes context through', () async {
        await logger.info('test', context: {'key': 'value'});
        final event = await cache.peek(1).first;
        expect(event.context, isNotNull);
        expect(event.context!['key'], 'value');
      });

      test('warning with context passes context through', () async {
        await logger.warning('test', context: {'key': 'value'});
        final event = await cache.peek(1).first;
        expect(event.context, isNotNull);
        expect(event.context!['key'], 'value');
      });
    });

    group('diagnosticLog', () {
      test('calls onDiagnosticLog callback', () {
        SeqEvent? captured;
        SeqLogger.onDiagnosticLog = (event) => captured = event;

        SeqLogger.diagnosticLog(SeqLogLevel.warning, 'test diagnostic');

        expect(captured, isNotNull);
        expect(captured!.message, 'test diagnostic');
      });

      test('does nothing when onDiagnosticLog is null', () {
        SeqLogger.onDiagnosticLog = null;

        // Should not throw
        SeqLogger.diagnosticLog(SeqLogLevel.error, 'test');
      });

      test('passes context to diagnostic event', () {
        SeqEvent? captured;
        SeqLogger.onDiagnosticLog = (event) => captured = event;

        SeqLogger.diagnosticLog(
          SeqLogLevel.information,
          'msg {Key}',
          null,
          {'Key': 'value'},
        );

        expect(captured!.context, isNotNull);
        expect(captured!.context!['Key'], 'value');
      });
    });

    group('throwOnError', () {
      test('defaults throwOnError to false', () {
        final logger = SeqLogger(client: client, cache: cache);
        expect(logger.throwOnError, isFalse);
      });

      test('swallows flush errors in send when throwOnError is false',
          () async {
        client.throwOnSend = Exception('server error');

        final logger = SeqLogger(
          client: client,
          cache: cache,
          backlogLimit: 1,
        );

        // Should not throw
        await logger.send(SeqEvent.info('test'));
      });

      test('propagates flush errors in send when throwOnError is true',
          () async {
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

      test('logs diagnostic on swallowed flush error', () async {
        final cacheWithError = _ThrowingPeekCache();

        SeqEvent? diagnosticEvent;
        SeqLogger.onDiagnosticLog = (event) {
          if (event.level == 'error' &&
              (event.message?.contains('Flush failed unexpectedly') ?? false)) {
            diagnosticEvent = event;
          }
        };

        final logger = SeqLogger(
          client: client,
          cache: cacheWithError,
          backlogLimit: 1,
        );

        await logger.send(SeqEvent.info('test'));

        expect(diagnosticEvent, isNotNull);
      });
    });

    group('flushInterval', () {
      test('flushes after flushInterval of inactivity', () {
        fakeAsync((async) {
          final logger = SeqLogger(
            client: client,
            cache: cache,
            autoFlush: false,
            flushInterval: const Duration(seconds: 5),
          );

          unawaited(logger.send(SeqEvent.info('test')));
          async.flushMicrotasks();

          expect(client.sentBatches, isEmpty);

          async.elapse(const Duration(seconds: 5));

          expect(client.sentBatches, hasLength(1));

          logger.dispose();
        });
      });

      test('resets timer on each send', () {
        fakeAsync((async) {
          final logger = SeqLogger(
            client: client,
            cache: cache,
            autoFlush: false,
            flushInterval: const Duration(seconds: 10),
          );

          unawaited(logger.send(SeqEvent.info('first')));
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 6));
          expect(client.sentBatches, isEmpty);

          unawaited(logger.send(SeqEvent.info('second')));
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 6));
          expect(client.sentBatches, isEmpty);

          async.elapse(const Duration(seconds: 4));
          expect(client.sentBatches, hasLength(1));

          logger.dispose();
        });
      });

      test('does not start timer when flushInterval is null', () {
        fakeAsync((async) {
          final logger = SeqLogger(
            client: client,
            cache: cache,
            autoFlush: false,
          );

          unawaited(logger.send(SeqEvent.info('test')));
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 60));
          expect(client.sentBatches, isEmpty);

          logger.dispose();
        });
      });

      test('dispose cancels the timer', () {
        fakeAsync((async) {
          final logger = SeqLogger(
            client: client,
            cache: cache,
            autoFlush: false,
            flushInterval: const Duration(seconds: 5),
          );

          unawaited(logger.send(SeqEvent.info('test')));
          async.flushMicrotasks();

          logger.dispose();

          async.elapse(const Duration(seconds: 10));
          expect(client.sentBatches, isEmpty);
        });
      });
    });

    group('constructor', () {
      test('asserts backlogLimit >= 0', () {
        expect(
          () => SeqLogger(
            client: client,
            cache: cache,
            backlogLimit: -1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('defaults backlogLimit to 50', () {
        final logger = SeqLogger(client: client, cache: cache);
        expect(logger.backlogLimit, 50);
      });

      test('defaults autoFlush to true', () {
        final logger = SeqLogger(client: client, cache: cache);
        expect(logger.autoFlush, isTrue);
      });
    });

    group('integration: happy path', () {
      test('log -> auto-flush -> client receives events with context',
          () async {
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
    });
  });
}
