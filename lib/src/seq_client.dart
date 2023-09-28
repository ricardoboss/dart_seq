import 'package:dart_seq/src/seq_event.dart';

/// The interface for all Seq client implementations. Implementations take on
/// the actual task of encoding and sending the events to the Seq server.
/// Additionally, if supported by the ingestion interface, the
/// [minimumLevelAccepted] SHOULD be updated with the value sent by the server.
abstract class SeqClient {
  /// Calling this method causes the events contained in the [events] stream to
  /// be sent to the Seq server. The future returned by this method is not
  /// guaranteed to be awaited, so implementers should not rely on it.
  Future<void> sendEvents(List<SeqEvent> events);

  /// Returns the minimum level accepted by the Seq server.
  String? get minimumLevelAccepted;
}
