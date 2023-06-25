enum SeqLogLevel {
  verbose('Verbose'),
  debug('Debug'),
  information('Information'),
  warning('Warning'),
  error('Error'),
  fatal('Fatal');

  final String value;

  const SeqLogLevel(this.value);
}
