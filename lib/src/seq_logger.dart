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

  factory SeqLogger.http({
    required String host,
    String? apiKey,
    int maxRetries = 5,
    SeqCache? cache,
    int backlogLimit = 50,
    SeqContext? globalContext,
    String? minimumLogLevel,
  }) {
    final httpConfig = SeqHttpClientConfiguration(host, apiKey, maxRetries);
    final httpClient = SeqHttpClient(httpConfig);

    final actualCache = cache ?? SeqInMemoryCache();

    return SeqLogger(
      client: httpClient,
      cache: actualCache,
      backlogLimit: backlogLimit,
      globalContext: globalContext,
      minimumLogLevel: minimumLogLevel,
    );
  }

  final SeqClient client;
  final SeqCache cache;
  final int backlogLimit;
  final SeqContext? globalContext;
  String? minimumLogLevel;

  SeqLogger({
    required this.client,
    required this.cache,
    this.backlogLimit = 50,
    this.globalContext,
    this.minimumLogLevel,
  }) : assert(backlogLimit >= 0, "backlogLimit must be >= 0");

  Future<void> send(SeqEvent event) async {
    event = addContext(event);
    if (!shouldLog(event)) {
      return;
    }

    await cache.record(event);

    if (shouldFlush()) {
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
    await client.sendEvents(cache.take());

    final newLogLevel = client.minimumLevelAccepted;
    if (minimumLogLevel != newLogLevel) {
      minimumLogLevel = newLogLevel;
    }
  }

  Future<void> log(
    SeqLogLevel level,
    String message, [
    SeqContext? context,
  ]) async {
    if (context != null && context.isEmpty) {
      context = null;
    }

    final event = SeqEvent.now(message, level.value, null, null, context);

    await send(event);
  }
}
