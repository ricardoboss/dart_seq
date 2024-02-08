/// The log level for Seq.
enum SeqLogLevel {
  /// Use the verbose log level for information that is useful for identifying
  /// and diagnosing problems.
  verbose('Verbose'),

  /// Use the debug log level for information that is primarily useful for
  /// developers.
  debug('Debug'),

  /// Use the information log level for information that is useful for
  /// monitoring the application.
  information('Information'),

  /// Use the warning log level for information that indicates a potential
  /// problem.
  warning('Warning'),

  /// Use the error log level for information that indicates a problem that
  /// should be addressed.
  error('Error'),

  /// Use the fatal log level for information that indicates a problem that
  /// should be addressed immediately.
  fatal('Fatal');

  const SeqLogLevel(this.value);

  /// The string value of the log level.
  final String value;
}
