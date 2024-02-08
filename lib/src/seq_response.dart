/// This class is used to parse the response from the Seq server.
class SeqResponse {
  /// Creates a new instance of [SeqResponse].
  SeqResponse(this.minimumLevelAccepted, this.error);

  /// Creates a new instance of [SeqResponse] from the given [json] object.
  factory SeqResponse.fromJson(Map<String, dynamic> json) {
    return SeqResponse(
      json['MinimumLevelAccepted'] as String?,
      json['Error'] as String?,
    );
  }

  /// The minimum level accepted by the Seq server, if any.
  final String? minimumLevelAccepted;

  /// The error message from the Seq server, if any.
  final String? error;
}
