class SeqHttpClientConfiguration {
  final String host;
  final String? apiKey;
  final int maxRetries;

  SeqHttpClientConfiguration(
    this.host, [
    this.apiKey,
    this.maxRetries = 5,
  ])  : assert(host.isNotEmpty, "host must not be empty"),
        assert(host.startsWith('http'), "the host must contain a scheme"),
        assert(null == apiKey || apiKey.isNotEmpty, "apiKey must not be empty"),
        assert(maxRetries >= 0, "maxRetries must be >= 0");
}
