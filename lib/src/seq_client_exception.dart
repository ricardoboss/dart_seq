import 'package:dart_seq/dart_seq.dart';

/// Exceptions thrown by [SeqClient] implementations when they fail to send
/// one or more events to the Seq server.
class SeqClientException extends Error {
  /// Creates a [SeqClientException] with the given message.
  SeqClientException(this.message, [this.innerException]);

  /// The exception message.
  final String message;

  /// The exception that caused this exception, if any.
  final Object? innerException;
}
