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

  /// Returns the events stored in the cache. After an event is read from the
  /// stream, it SHOULD no longer be included in the [count] and MUST not be
  /// returned by [take] again.
  Stream<SeqEvent> take();
}
