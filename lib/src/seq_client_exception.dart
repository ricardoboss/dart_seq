import 'package:dart_seq/dart_seq.dart';

/// Exceptions thrown by [SeqClient] implementations when they fail to send
/// one or more events to the Seq server.
class SeqClientException {
  /// The exception message.
  final String message;

  /// The exception that caused this exception, if any.
  final Object? innerException;

  /// The stack trace of the exception, if any.
  final StackTrace? stackTrace;

  /// Creates a [SeqClientException] with the given message.
  SeqClientException(this.message, [this.innerException, this.stackTrace]);
}
