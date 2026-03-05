import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqInMemoryCache', () {
    late SeqInMemoryCache cache;

    setUp(() {
      cache = SeqInMemoryCache();
    });

    test('starts empty', () {
      expect(cache.count, 0);
    });

    test('record adds events and count reflects them', () async {
      final event1 = SeqEvent.now('one');
      final event2 = SeqEvent.now('two');

      await cache.record(event1);
      expect(cache.count, 1);

      await cache.record(event2);
      expect(cache.count, 2);
    });

    test('peek returns events in FIFO order without removing', () async {
      final event1 = SeqEvent.now('first');
      final event2 = SeqEvent.now('second');
      await cache.record(event1);
      await cache.record(event2);

      final events = await cache.peek(1).toList();

      expect(events, hasLength(1));
      expect(events.first, same(event1));
      expect(cache.count, 2);
    });

    test('peek returns all when count exceeds cache size', () async {
      await cache.record(SeqEvent.now('a'));
      await cache.record(SeqEvent.now('b'));

      final events = await cache.peek(10).toList();

      expect(events, hasLength(2));
    });

    test('remove removes first N events', () async {
      final event1 = SeqEvent.now('first');
      final event2 = SeqEvent.now('second');
      final event3 = SeqEvent.now('third');
      await cache.record(event1);
      await cache.record(event2);
      await cache.record(event3);

      await cache.remove(1);

      expect(cache.count, 2);
      final remaining = await cache.peek(2).toList();
      expect(remaining[0], same(event2));
      expect(remaining[1], same(event3));
    });

    test('remove clamps to cache size', () async {
      await cache.record(SeqEvent.now('a'));
      await cache.record(SeqEvent.now('b'));

      await cache.remove(10);

      expect(cache.count, 0);
    });
  });
}
