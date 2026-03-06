import 'package:dart_seq/src/seq_client_exception.dart';
import 'package:dart_seq/src/seq_event.dart';
import 'package:dart_seq/src/seq_event_result.dart';

/// The interface for all Seq client implementations. Implementations take on
/// the actual task of encoding and sending the events to the Seq server.
/// Additionally, if supported by the ingestion interface, the
/// [minimumLevelAccepted] SHOULD be updated with the value sent by the server.
abstract class SeqClient {
  /// Sends a batch of [events] to the Seq server and returns per-event results.
  ///
  /// ### Return value
  ///
  /// Returns a [SeqEventResult] for each event. Each result is either
  /// successful ([SeqEventResult.isSuccess]) or failed, with failed results
  /// carrying an [SeqEventResult.error] and an
  /// [SeqEventResult.isPermanent] flag.
  ///
  /// ### Throwing
  ///
  /// The method **throws** on total failures where no per-event information
  /// is available (network errors, authentication failures, etc.). When this
  /// method throws, the caller should assume **none** of the events were sent.
  ///
  /// ### Implementation notes
  ///
  /// - Implementations SHOULD throw [SeqClientException] (or a subclass) on
  ///   total failure so that callers can reliably match on the exception type.
  /// - The returned future is not guaranteed to be awaited by all callers,
  ///   so implementers should not rely on the caller observing the result.
  Future<Iterable<SeqEventResult>> sendEvents(Iterable<SeqEvent> events);

  /// Returns the minimum level accepted by the Seq server.
  ///
  /// Updated after each successful [sendEvents] call if the server includes
  /// a minimum level header in its response (e.g. `X-Seq-MinimumLevelAccepted`).
  /// Returns `null` if the server has not specified a minimum level.
  String? get minimumLevelAccepted;
}
