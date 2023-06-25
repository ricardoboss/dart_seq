class SeqResponse {
  final String? minimumLevelAccepted;
  final String? error;

  SeqResponse(this.minimumLevelAccepted, this.error);

  factory SeqResponse.fromJson(Map<String, dynamic> json) {
    return SeqResponse(
      json['MinimumLevelAccepted'] as String?,
      json['Error'] as String?,
    );
  }
}
