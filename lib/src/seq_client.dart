import 'package:dart_seq/src/seq_client_exception.dart';
import 'package:dart_seq/src/seq_event.dart';
import 'package:dart_seq/src/seq_event_sent_result.dart';

/// The interface for all Seq client implementations. Implementations take on
/// the actual task of encoding and sending the events to the Seq server.
/// Additionally, if supported by the ingestion interface, the
/// [minimumLevelAccepted] SHOULD be updated with the value sent by the server.
abstract class SeqClient {
  /// Sends a batch of [events] to the Seq server and returns per-event results.
  ///
  /// ## Return value
  ///
  /// Returns a [SeqEventSentResult] for each event in the batch:
  ///
  /// - **All succeeded**: every result has `isSuccess: true`. This is the
  ///   common case when the server accepts the entire batch (HTTP 201).
  /// - **Partial failure**: a mix of succeeded and failed results. This
  ///   happens when the batch is rejected (e.g. HTTP 400) and the
  ///   implementation retries events individually to isolate the bad ones.
  ///
  /// ## Throwing
  ///
  /// The method **throws** on total failures where no per-event information
  /// is available (network errors, authentication failures, etc.). When this
  /// method throws, the caller should assume **none** of the events were sent.
  ///
  /// ## `isPermanent` flag
  ///
  /// Failed results should set [SeqEventSentResult.isPermanent] to `true`
  /// when the failure is non-recoverable (e.g. HTTP 400 — the event itself
  /// is malformed). This tells the default flush error handling to drop the
  /// event instead of retrying. Transient failures (network errors, server
  /// overload) should leave `isPermanent` as `false` so they are re-queued.
  ///
  /// ## Error handling by `SeqLogger.flush()`
  ///
  /// When results are returned (no exception):
  /// 1. All events are removed from cache.
  /// 2. Permanently failed events are dropped. Transient failures are
  ///    re-queued. If `onFlushError` is set, it overrides this default.
  ///
  /// When this method throws (total failure):
  /// 1. Events are **kept in cache** (safe default — they were never sent).
  /// 2. If `onFlushError` is set, it is called with synthetic failure results
  ///    so the caller can decide what to do.
  ///
  /// ## Implementation notes
  ///
  /// - Implementations SHOULD throw [SeqClientException] (or a subclass) on
  ///   total failure so that callers can reliably match on the exception type.
  /// - The returned future is not guaranteed to be awaited by all callers
  ///   (e.g. timer-triggered flushes use `unawaited`), so implementers should
  ///   not rely on the caller observing the result.
  Future<List<SeqEventSentResult>> sendEvents(List<SeqEvent> events);

  /// Returns the minimum level accepted by the Seq server.
  ///
  /// Updated after each successful [sendEvents] call if the server includes
  /// a minimum level header in its response (e.g. `X-Seq-MinimumLevelAccepted`).
  /// Returns `null` if the server has not specified a minimum level.
  String? get minimumLevelAccepted;
}
