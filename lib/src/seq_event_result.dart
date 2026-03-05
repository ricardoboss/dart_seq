import 'package:dart_seq/src/seq_event.dart';

/// The result of attempting to send a single [SeqEvent] to the Seq server.
///
/// Returned as part of a list from `SeqClient.sendEvents` to communicate
/// per-event success or failure - for example after a batch 400 triggers
/// individual retries.
///
/// Use the [SeqEventResult.success] and [SeqEventResult.failure] factory
/// methods to create instances.
class SeqEventResult {
  SeqEventResult._({
    required this.event,
    required this.isSuccess,
    this.error,
    this.isPermanent = false,
  });

  /// Creates a successful result for [event].
  factory SeqEventResult.success(SeqEvent event) =>
      SeqEventResult._(event: event, isSuccess: true);

  /// Creates a failed result for [event] with the given [error].
  ///
  /// Set [isPermanent] to `true` when the failure is non-recoverable (e.g.
  /// the server rejected the event as malformed with HTTP 400). Permanent
  /// failures will **not** be retried by the default flush error handling.
  ///
  /// Leave [isPermanent] as `false` (default) for transient failures like
  /// network errors or server overload, where retrying may succeed.
  factory SeqEventResult.failure(
    SeqEvent event,
    Object error, {
    bool isPermanent = false,
  }) =>
      SeqEventResult._(
        event: event,
        isSuccess: false,
        error: error,
        isPermanent: isPermanent,
      );

  /// The event this result refers to.
  final SeqEvent event;

  /// Whether the event was successfully sent to the server.
  final bool isSuccess;

  /// The error that caused the failure, if any.
  final Object? error;

  /// Whether this failure is permanent and retrying would be futile.
  ///
  /// `true` - the event itself is invalid (e.g. server returned HTTP 400).
  /// Retrying will produce the same rejection. The default flush error
  /// handling drops these events.
  ///
  /// `false` (default) - the failure may be transient (e.g. network error,
  /// server overload). The default flush error handling re-queues these
  /// events for a future flush attempt.
  ///
  /// Always `false` when [isSuccess] is `true`.
  final bool isPermanent;
}
