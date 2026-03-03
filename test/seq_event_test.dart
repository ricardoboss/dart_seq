import 'dart:convert';

import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqEvent', () {
    group('constructor', () {
      test('sets all fields correctly', () {
        final timestamp = DateTime.utc(2024);
        final context = <String, dynamic>{'key': 'value'};
        final renderings = <String, dynamic>{'key': 'rendered'};
        final exception = Exception('test');

        final event = SeqEvent(
          timestamp: timestamp,
          message: 'message',
          messageTemplate: 'template {key}',
          level: 'Information',
          exception: exception,
          id: 42,
          renderings: renderings,
          context: context,
        );

        expect(event.timestamp, timestamp);
        expect(event.message, 'message');
        expect(event.messageTemplate, 'template {key}');
        expect(event.level, 'Information');
        expect(event.exception, exception);
        expect(event.id, 42);
        expect(event.renderings, renderings);
        expect(event.context, context);
      });

      test('allows null optional fields', () {
        final timestamp = DateTime.utc(2024);

        final event = SeqEvent(timestamp: timestamp);

        expect(event.timestamp, timestamp);
        expect(event.message, isNull);
        expect(event.messageTemplate, isNull);
        expect(event.level, isNull);
        expect(event.exception, isNull);
        expect(event.id, isNull);
        expect(event.renderings, isNull);
        expect(event.context, isNull);
      });

      test('sets new CLEF properties', () {
        final spanStart = DateTime.utc(2024, 6, 1, 12);
        final event = SeqEvent(
          timestamp: DateTime.utc(2024, 6),
          traceId: 'abc123',
          spanId: 'span1',
          parentSpanId: 'parent1',
          spanStart: spanStart,
          scope: 'MyService',
          resourceAttributes: {'service.name': 'api'},
          spanKind: 'Server',
        );

        expect(event.traceId, 'abc123');
        expect(event.spanId, 'span1');
        expect(event.parentSpanId, 'parent1');
        expect(event.spanStart, spanStart);
        expect(event.scope, 'MyService');
        expect(event.resourceAttributes, {'service.name': 'api'});
        expect(event.spanKind, 'Server');
      });
    });

    group('SeqEvent.now', () {
      test('sets timestamp to current time', () {
        final before = DateTime.now();
        final event = SeqEvent.now('test');
        final after = DateTime.now();

        expect(
          event.timestamp.isAfter(before) || event.timestamp == before,
          isTrue,
        );
        expect(
          event.timestamp.isBefore(after) || event.timestamp == after,
          isTrue,
        );
      });

      test('without context sets message and no messageTemplate', () {
        final event = SeqEvent.now('hello');

        expect(event.message, 'hello');
        expect(event.messageTemplate, isNull);
        expect(event.renderings, isNull);
      });

      test('with context sets messageTemplate and renderings', () {
        final event = SeqEvent.now(
          'hello {Name}',
          null,
          null,
          null,
          {'Name': 'World'},
        );

        expect(event.message, isNull);
        expect(event.messageTemplate, 'hello {Name}');
        expect(event.renderings, isNotNull);
        expect(event.renderings!['Name'], 'World');
        expect(event.context, {'Name': 'World'});
      });

      test('forwards level, id, and exception', () {
        final exception = Exception('fail');
        final event = SeqEvent.now('msg', 'Error', 99, exception);

        expect(event.level, 'Error');
        expect(event.id, 99);
        expect(event.exception, exception);
      });

      test('forwards new CLEF properties', () {
        final spanStart = DateTime.utc(2024, 6);
        final event = SeqEvent.now(
          'msg',
          null,
          null,
          null,
          null,
          'trace1',
          'span1',
          'parent1',
          spanStart,
          'MyScope',
          {'key': 'val'},
          'Client',
        );

        expect(event.traceId, 'trace1');
        expect(event.spanId, 'span1');
        expect(event.parentSpanId, 'parent1');
        expect(event.spanStart, spanStart);
        expect(event.scope, 'MyScope');
        expect(event.resourceAttributes, {'key': 'val'});
        expect(event.spanKind, 'Client');
      });
    });

    group('level factories', () {
      test('verbose sets correct level', () {
        final event = SeqEvent.verbose('msg');
        expect(event.level, 'Verbose');
      });

      test('debug sets correct level', () {
        final event = SeqEvent.debug('msg');
        expect(event.level, 'Debug');
      });

      test('info sets correct level', () {
        final event = SeqEvent.info('msg');
        expect(event.level, 'Information');
      });

      test('warning sets correct level', () {
        final event = SeqEvent.warning('msg');
        expect(event.level, 'Warning');
      });

      test('error sets correct level', () {
        final event = SeqEvent.error('msg');
        expect(event.level, 'Error');
      });

      test('fatal sets correct level', () {
        final event = SeqEvent.fatal('msg');
        expect(event.level, 'Fatal');
      });

      test('level factories pass context through', () {
        final event = SeqEvent.info('hello {X}', {'X': 42});

        expect(event.messageTemplate, 'hello {X}');
        expect(event.message, isNull);
        expect(event.context, {'X': 42});
        expect(event.renderings!['X'], 42);
      });
    });

    group('fromMap', () {
      test('parses all CLEF properties', () {
        final map = <String, dynamic>{
          '@t': '2024-01-01T00:00:00.000Z',
          '@m': 'rendered message',
          '@mt': 'template {key}',
          '@l': 'Warning',
          '@x': 'some exception',
          '@i': '42',
          '@r': <String, dynamic>{'key': 'rendered'},
        };

        final event = SeqEvent.fromMap(map);

        expect(event.timestamp, DateTime.utc(2024));
        expect(event.message, 'rendered message');
        expect(event.messageTemplate, 'template {key}');
        expect(event.level, 'Warning');
        expect(event.exception, 'some exception');
        expect(event.id, 42);
        expect(event.renderings, {'key': 'rendered'});
      });

      test('defaults timestamp to DateTime.now when @t is missing', () {
        final before = DateTime.now();
        final event = SeqEvent.fromMap({'@m': 'hello'});
        final after = DateTime.now();

        expect(
          event.timestamp.isAfter(before) || event.timestamp == before,
          isTrue,
        );
        expect(
          event.timestamp.isBefore(after) || event.timestamp == after,
          isTrue,
        );
      });

      test('extra keys land in context', () {
        final map = <String, dynamic>{
          '@t': '2024-01-01T00:00:00.000Z',
          '@m': 'msg',
          'App': 'MyApp',
          'Version': 42,
        };

        final event = SeqEvent.fromMap(map);

        expect(event.context, isNotNull);
        expect(event.context!['App'], 'MyApp');
        expect(event.context!['Version'], 42);
      });

      test('@x with non-string value lands in exception', () {
        final inner = {'detail': 'info'};
        final map = <String, dynamic>{
          '@t': '2024-01-01T00:00:00.000Z',
          '@x': inner,
        };

        final event = SeqEvent.fromMap(map);

        expect(event.exception, inner);
      });

      test('returns null context when no extra keys', () {
        final map = <String, dynamic>{
          '@t': '2024-01-01T00:00:00.000Z',
          '@m': 'msg',
        };

        final event = SeqEvent.fromMap(map);

        expect(event.context, isNull);
      });

      test('parses new CLEF properties', () {
        final map = <String, dynamic>{
          '@t': '2024-01-01T00:00:00.000Z',
          '@m': 'msg',
          '@tr': 'trace123',
          '@sp': 'span456',
          '@ps': 'parent789',
          '@st': '2024-01-01T00:00:00.000Z',
          '@sc': 'MyScope',
          '@ra': <String, dynamic>{'service.name': 'api'},
          '@sk': 'Server',
        };

        final event = SeqEvent.fromMap(map);

        expect(event.traceId, 'trace123');
        expect(event.spanId, 'span456');
        expect(event.parentSpanId, 'parent789');
        expect(event.spanStart, DateTime.utc(2024));
        expect(event.scope, 'MyScope');
        expect(event.resourceAttributes, {'service.name': 'api'});
        expect(event.spanKind, 'Server');
      });
    });

    group('toMap', () {
      test('serializes timestamp as UTC ISO8601', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024, 3, 15, 10, 30),
          message: 'msg',
        );

        final map = event.toMap();

        expect(map['@t'], '2024-03-15T10:30:00.000Z');
      });

      test('includes message when set', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'hello',
        );

        expect(event.toMap()['@m'], 'hello');
      });

      test('includes messageTemplate when set', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          messageTemplate: 'hello {Name}',
        );

        expect(event.toMap()['@mt'], 'hello {Name}');
      });

      test('includes level when set', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          level: 'Error',
        );

        expect(event.toMap()['@l'], 'Error');
      });

      test('serializes exception message to @x', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          exception: Exception('boom'),
        );

        final map = event.toMap();

        expect(map['@x'], 'Exception: boom');
      });

      test('serializes string exception as-is', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          exception: 'something went wrong',
        );

        final map = event.toMap();

        expect(map['@x'], 'something went wrong');
      });

      test('excludes null optional fields from map', () {
        final event = SeqEvent(timestamp: DateTime.utc(2024));

        final map = event.toMap();

        expect(map.containsKey('@m'), isFalse);
        expect(map.containsKey('@mt'), isFalse);
        expect(map.containsKey('@l'), isFalse);
        expect(map.containsKey('@x'), isFalse);
        expect(map.containsKey('@i'), isFalse);
        expect(map.containsKey('@r'), isFalse);
        expect(map.containsKey('@t'), isTrue);
      });

      test('excludes empty renderings', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          renderings: <String, dynamic>{},
        );

        expect(event.toMap().containsKey('@r'), isFalse);
      });

      test('includes id when set', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          id: 7,
        );

        expect(event.toMap()['@i'], 7);
      });

      test('context keys starting with @ get double-escaped', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          context: {'@custom': 'value'},
        );

        final map = event.toMap();

        expect(map.containsKey('@@custom'), isTrue);
        expect(map['@@custom'], 'value');
      });

      test('known Seq keys in context are not double-escaped', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          context: {'@tr': 'trace-in-context'},
        );

        final map = event.toMap();

        expect(map.containsKey('@tr'), isTrue);
        expect(map.containsKey('@@tr'), isFalse);
        expect(map['@tr'], 'trace-in-context');
      });

      test('context values are included as top-level keys', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          messageTemplate: 'tmpl',
          context: {'App': 'Test', 'Count': 5},
        );

        final map = event.toMap();

        expect(map['App'], 'Test');
        expect(map['Count'], 5);
      });

      test('serializes new CLEF properties', () {
        final spanStart = DateTime.utc(2024, 6, 1, 12);
        final event = SeqEvent(
          timestamp: DateTime.utc(2024, 6),
          message: 'msg',
          traceId: 'trace1',
          spanId: 'span1',
          parentSpanId: 'parent1',
          spanStart: spanStart,
          scope: 'MyScope',
          resourceAttributes: {'service.name': 'api'},
          spanKind: 'Server',
        );

        final map = event.toMap();

        expect(map['@tr'], 'trace1');
        expect(map['@sp'], 'span1');
        expect(map['@ps'], 'parent1');
        expect(map['@st'], '2024-06-01T12:00:00.000Z');
        expect(map['@sc'], 'MyScope');
        expect(map['@ra'], {'service.name': 'api'});
        expect(map['@sk'], 'Server');
      });

      test('excludes null new CLEF properties', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
        );

        final map = event.toMap();

        expect(map.containsKey('@tr'), isFalse);
        expect(map.containsKey('@sp'), isFalse);
        expect(map.containsKey('@ps'), isFalse);
        expect(map.containsKey('@st'), isFalse);
        expect(map.containsKey('@sc'), isFalse);
        expect(map.containsKey('@ra'), isFalse);
        expect(map.containsKey('@sk'), isFalse);
      });

      test('excludes empty resourceAttributes', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          resourceAttributes: <String, dynamic>{},
        );

        final map = event.toMap();

        expect(map.containsKey('@ra'), isFalse);
      });
    });

    group('toJson', () {
      test('is an alias for toMap', () {
        final event = SeqEvent.info('test');

        expect(event.toJson(), event.toMap());
      });

      test('is compatible with jsonEncode', () {
        final event = SeqEvent.info('hello');

        final encoded = jsonEncode(event);

        expect(encoded, isA<String>());

        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded['@l'], 'Information');
      });
    });

    group('withAddedContext', () {
      test('returns same instance when context is null', () {
        final event = SeqEvent.info('test');

        final result = event.withAddedContext(null);

        expect(identical(result, event), isTrue);
      });

      test('merges new context with existing', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          context: {'A': 1},
        );

        final result = event.withAddedContext({'B': 2});

        expect(result.context, {'A': 1, 'B': 2});
      });

      test('new context overrides existing keys', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          context: {'A': 1},
        );

        final result = event.withAddedContext({'A': 99});

        expect(result.context!['A'], 99);
      });

      test('preserves all other fields', () {
        final exception = Exception('err');
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
          messageTemplate: 'tmpl',
          level: 'Error',
          exception: exception,
          id: 42,
          renderings: {'key': 'val'},
          context: {'existing': true},
          traceId: 'tr1',
          spanId: 'sp1',
          parentSpanId: 'ps1',
          spanStart: DateTime.utc(2024),
          scope: 'sc1',
          resourceAttributes: {'k': 'v'},
          spanKind: 'Client',
        );

        final result = event.withAddedContext({'new': 'ctx'});

        expect(result.timestamp, event.timestamp);
        expect(result.message, event.message);
        expect(result.messageTemplate, event.messageTemplate);
        expect(result.level, event.level);
        expect(result.exception, event.exception);
        expect(result.id, event.id);
        expect(result.renderings, event.renderings);
        expect(result.traceId, event.traceId);
        expect(result.spanId, event.spanId);
        expect(result.parentSpanId, event.parentSpanId);
        expect(result.spanStart, event.spanStart);
        expect(result.scope, event.scope);
        expect(result.resourceAttributes, event.resourceAttributes);
        expect(result.spanKind, event.spanKind);
      });

      test('adds context when event has no existing context', () {
        final event = SeqEvent(
          timestamp: DateTime.utc(2024),
          message: 'msg',
        );

        final result = event.withAddedContext({'key': 'value'});

        expect(result.context, {'key': 'value'});
      });
    });

    group('_renderValue', () {
      test('primitives pass through in renderings', () {
        final event = SeqEvent.now(
          'msg {A} {B} {C} {D}',
          null,
          null,
          null,
          {'A': 42, 'B': true, 'C': 'hello', 'D': null},
        );

        expect(event.renderings!['A'], 42);
        expect(event.renderings!['B'], true);
        expect(event.renderings!['C'], 'hello');
        expect(event.renderings!['D'], isNull);
      });

      test('complex objects get jsonEncoded in renderings', () {
        final event = SeqEvent.now(
          'msg {Data}',
          null,
          null,
          null,
          {
            'Data': {'nested': 'value'},
          },
        );

        expect(event.renderings!['Data'], jsonEncode({'nested': 'value'}));
      });

      test('list values get jsonEncoded in renderings', () {
        final event = SeqEvent.now(
          'msg {Items}',
          null,
          null,
          null,
          {
            'Items': [1, 2, 3],
          },
        );

        expect(event.renderings!['Items'], jsonEncode([1, 2, 3]));
      });
    });

    group('fromMap/toMap round-trip', () {
      test('preserves data through serialization cycle', () {
        final original = SeqEvent(
          timestamp: DateTime.utc(2024, 6, 15, 12, 30),
          message: 'rendered msg',
          messageTemplate: 'template {Key}',
          level: 'Warning',
          renderings: {'Key': 'rendered'},
          context: {'App': 'Test', 'Count': 5},
        );

        final map = original.toMap();
        final restored = SeqEvent.fromMap(map);

        expect(restored.timestamp, original.timestamp);
        expect(restored.message, original.message);
        expect(restored.messageTemplate, original.messageTemplate);
        expect(restored.level, original.level);
        expect(restored.renderings, original.renderings);
        expect(restored.context!['App'], 'Test');
        expect(restored.context!['Count'], 5);
      });

      test('preserves new CLEF properties through round-trip', () {
        final spanStart = DateTime.utc(2024, 6, 1, 12);
        final original = SeqEvent(
          timestamp: DateTime.utc(2024, 6, 15),
          message: 'msg',
          traceId: 'trace1',
          spanId: 'span1',
          parentSpanId: 'parent1',
          spanStart: spanStart,
          scope: 'MyScope',
          resourceAttributes: {'service.name': 'api'},
          spanKind: 'Server',
        );

        final map = original.toMap();
        final restored = SeqEvent.fromMap(map);

        expect(restored.traceId, 'trace1');
        expect(restored.spanId, 'span1');
        expect(restored.parentSpanId, 'parent1');
        expect(restored.spanStart, spanStart);
        expect(restored.scope, 'MyScope');
        expect(restored.resourceAttributes, {'service.name': 'api'});
        expect(restored.spanKind, 'Server');
      });
    });
  });
}
