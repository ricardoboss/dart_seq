import 'package:dart_seq/dart_seq.dart';

class SeqLogger {
  static int compareLevels(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    final aLevel = levelToInt(a);
    final bLevel = levelToInt(b);

    return aLevel.compareTo(bLevel);
  }

  static int levelToInt(String level) {
    return switch (level) {
      "Verbose" => 0,
      "Debug" => 1,
      "Information" => 2,
      "Warning" => 3,
      "Error" => 4,
      "Fatal" => 5,
      _ => -1,
    };
  }

  static void Function(SeqEvent event)? onDiagnosticLog;

  static void diagnosticLog(
    SeqLogLevel level,
    String message, [
    Object? exception,
    SeqContext? context,
  ]) {
    final event = SeqEvent.now(message, level.name, 0, exception, context);

    onDiagnosticLog?.call(event);
  }

  factory SeqLogger.http({
    required String host,
    String? apiKey,
    int maxRetries = 5,
    SeqCache? cache,
    int backlogLimit = 50,
    SeqContext? globalContext,
    String? minimumLogLevel,
    bool autoFlush = true,
    Duration Function(int tries)? httpBackoff,
  }) {
    final httpClient = SeqHttpClient(
      host: host,
      apiKey: apiKey,
      maxRetries: maxRetries,
      backoff: httpBackoff,
    );

    final actualCache = cache ?? SeqInMemoryCache();

    return SeqLogger(
      client: httpClient,
      cache: actualCache,
      backlogLimit: backlogLimit,
      globalContext: globalContext,
      minimumLogLevel: minimumLogLevel,
      autoFlush: autoFlush,
    );
  }

  final SeqClient client;
  final SeqCache cache;
  final int backlogLimit;
  final SeqContext? globalContext;
  final bool autoFlush;
  String? minimumLogLevel;

  SeqLogger({
    required this.client,
    required this.cache,
    this.backlogLimit = 50,
    this.globalContext,
    this.minimumLogLevel,
    this.autoFlush = true,
  }) : assert(backlogLimit >= 0, "backlogLimit must be >= 0");

  Future<void> send(SeqEvent event) async {
    if (!shouldLog(event)) {
      return;
    }

    event = addContext(event);

    await cache.record(event);

    if (autoFlush && shouldFlush()) {
      await flush();
    }
  }

  SeqEvent addContext(SeqEvent event) {
    return event.withAddedContext(globalContext);
  }

  bool shouldLog(SeqEvent event) {
    return minimumLogLevel == null ||
        compareLevels(minimumLogLevel, event.level) <= 0;
  }

  bool shouldFlush() => cache.count >= backlogLimit;

  Future<void> flush() async {
    diagnosticLog(SeqLogLevel.verbose, "Flushing events");

    final eventsToBeSent = await cache.peek(backlogLimit).toList();

    await client.sendEvents(eventsToBeSent);

    await cache.remove(eventsToBeSent.length);

    final newLogLevel = client.minimumLevelAccepted;
    if (minimumLogLevel != newLogLevel) {
      diagnosticLog(
        SeqLogLevel.verbose,
        "Accepted new log level {MinimumLogLevel}",
        null,
        {'MinimumLogLevel': newLogLevel},
      );

      minimumLogLevel = newLogLevel;
    }
  }

  Future<void> log(
    SeqLogLevel level,
    String message, [
    Object? exception,
    SeqContext? context,
  ]) async {
    if (context != null && context.isEmpty) {
      context = null;
    }

    final event = SeqEvent.now(message, level.value, null, exception, context);

    await send(event);
  }

  Future<void> verbose(String message, [SeqContext? context]) =>
      log(SeqLogLevel.verbose, message, null, context);

  Future<void> debug(String message, [SeqContext? context]) =>
      log(SeqLogLevel.debug, message, null, context);

  Future<void> info(String message, [SeqContext? context]) =>
      log(SeqLogLevel.information, message, null, context);

  Future<void> warning(String message, [SeqContext? context]) =>
      log(SeqLogLevel.warning, message, null, context);

  Future<void> error(String message,
          [Object? exception, SeqContext? context]) =>
      log(SeqLogLevel.error, message, exception, context);

  Future<void> fatal(String message,
          [Object? exception, SeqContext? context]) =>
      log(SeqLogLevel.fatal, message, exception, context);
}
