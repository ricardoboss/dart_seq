import 'package:dart_seq/dart_seq.dart';

/// Exceptions thrown by [SeqClient] implementations when they fail to send
/// one or more events to the Seq server.
class SeqClientException implements Exception {
  /// Creates a [SeqClientException] with the given message.
  SeqClientException(this.message, [this.innerException, this.innerStackTrace]);

  /// The exception message.
  final String message;

  /// The exception that caused this exception, if any.
  final Object? innerException;

  /// The stack trace of the exception that caused this exception, if any.
  final StackTrace? innerStackTrace;

  /// Whether the error is retryable.
  ///
  /// When `true` (default), the caller should keep events in cache and retry
  /// on the next flush. When `false`, retrying the same batch will produce the
  /// same error (e.g. payload too large, malformed request).
  bool get isRetryable => true;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('SeqClientException: ')
      ..write(message);

    if (innerException != null) {
      buffer
        ..write('; innerException: ')
        ..write(innerException);
    }

    return buffer.toString();
  }
}
