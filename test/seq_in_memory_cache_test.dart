import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('In memory cache', () {
    test('Record', () async {
      // Arrange
      final cache = SeqInMemoryCache();
      final event = SeqEvent.now('test');
      final event2 = SeqEvent.now('test2');

      // Act
      await cache.record(event);
      await cache.record(event2);

      // Assert
      expect(cache.count, 2);
    });

    test('Peek', () async {
      // Arrange
      final cache = SeqInMemoryCache();
      final event = SeqEvent.now('test');
      final event2 = SeqEvent.now('test2');

      await cache.record(event);
      await cache.record(event2);

      // Act
      final events = await cache.peek(1).toList();

      // Assert
      expect(cache.count, 2);
      expect(events.length, 1);
      expect(events.first, event);
    });

    test('Remove', () async {
      // Arrange
      final cache = SeqInMemoryCache();
      final event = SeqEvent.now('test');
      final event2 = SeqEvent.now('test2');

      await cache.record(event);
      await cache.record(event2);

      // Act
      await cache.remove(1);

      // Assert
      expect(cache.count, 1);
    });
  });
}
