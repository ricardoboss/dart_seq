class SeqLoggerConfiguration {
  final int backlogLimit;
  final Map<String, dynamic>? globalContext;
  final String? minimumLogLevel;

  const SeqLoggerConfiguration([
    this.backlogLimit = 50,
    this.globalContext,
    this.minimumLogLevel,
  ]) : assert(backlogLimit >= 0, "backlogLimit must be >= 0");
}
