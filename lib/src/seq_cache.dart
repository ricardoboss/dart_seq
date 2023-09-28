import 'package:dart_seq/dart_seq.dart';

/// The interface for all cache implementations. The default implementation is
/// [SeqInMemoryCache], which simply stores the events in a list.
abstract class SeqCache {
  /// The number of events currently stored in the cache. This value is queried
  /// every time a new log is added in order to determine whether to flush the
  /// cached events. Implementers should consider caching/estimating this value
  /// if no direct access to the number of events is possible.
  int get count;

  /// Adds a new event to the cache. The future returned by this method is not
  /// guaranteed to be awaited, so implementers should not rely on it.
  Future<void> record(SeqEvent event);

  /// Returns [count] events stored in the cache.
  /// The returned stream contains the next [count] events in the cache, or all
  /// events if [count] is greater than the number of events in the cache.
  /// The returned events are not removed from the cache.
  Stream<SeqEvent> peek(int count);

  /// Removes [count] events from the cache.
  /// The returned stream contains the next [count] events in the cache, or all
  /// events if [count] is greater than the number of events in the cache.
  Future<void> remove(int count);
}
