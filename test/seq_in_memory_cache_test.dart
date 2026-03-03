import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqInMemoryCache', () {
    late SeqInMemoryCache cache;

    setUp(() {
      cache = SeqInMemoryCache();
    });

    group('record', () {
      test('adds event to cache', () async {
        await cache.record(SeqEvent.now('test'));

        expect(cache.count, 1);
      });

      test('adds multiple events', () async {
        await cache.record(SeqEvent.now('one'));
        await cache.record(SeqEvent.now('two'));
        await cache.record(SeqEvent.now('three'));

        expect(cache.count, 3);
      });
    });

    group('count', () {
      test('returns 0 for empty cache', () {
        expect(cache.count, 0);
      });

      test('reflects number of recorded events', () async {
        await cache.record(SeqEvent.now('a'));
        expect(cache.count, 1);

        await cache.record(SeqEvent.now('b'));
        expect(cache.count, 2);
      });
    });

    group('peek', () {
      test('returns requested number of events', () async {
        final event1 = SeqEvent.now('first');
        final event2 = SeqEvent.now('second');
        await cache.record(event1);
        await cache.record(event2);

        final events = await cache.peek(1).toList();

        expect(events, hasLength(1));
        expect(events.first, event1);
      });

      test('returns all events when count > cache size', () async {
        final event1 = SeqEvent.now('first');
        final event2 = SeqEvent.now('second');
        await cache.record(event1);
        await cache.record(event2);

        final events = await cache.peek(10).toList();

        expect(events, hasLength(2));
      });

      test('returns empty stream when count is 0', () async {
        await cache.record(SeqEvent.now('test'));

        final events = await cache.peek(0).toList();

        expect(events, isEmpty);
      });

      test('does not remove events from cache', () async {
        await cache.record(SeqEvent.now('test'));

        await cache.peek(1).toList();

        expect(cache.count, 1);
      });

      test('preserves FIFO order', () async {
        final first = SeqEvent.now('first');
        final second = SeqEvent.now('second');
        final third = SeqEvent.now('third');
        await cache.record(first);
        await cache.record(second);
        await cache.record(third);

        final events = await cache.peek(3).toList();

        expect(events[0], first);
        expect(events[1], second);
        expect(events[2], third);
      });

      test('returns empty stream for empty cache', () async {
        final events = await cache.peek(5).toList();

        expect(events, isEmpty);
      });
    });

    group('remove', () {
      test('removes first N events', () async {
        final event1 = SeqEvent.now('first');
        final event2 = SeqEvent.now('second');
        final event3 = SeqEvent.now('third');
        await cache.record(event1);
        await cache.record(event2);
        await cache.record(event3);

        await cache.remove(1);

        expect(cache.count, 2);
        final remaining = await cache.peek(2).toList();
        expect(remaining[0], event2);
        expect(remaining[1], event3);
      });

      test('removes all when count > cache size', () async {
        await cache.record(SeqEvent.now('a'));
        await cache.record(SeqEvent.now('b'));

        await cache.remove(10);

        expect(cache.count, 0);
      });

      test('removes nothing when count is 0', () async {
        await cache.record(SeqEvent.now('test'));

        await cache.remove(0);

        expect(cache.count, 1);
      });

      test('handles remove on empty cache', () async {
        await cache.remove(5);

        expect(cache.count, 0);
      });
    });
  });
}
