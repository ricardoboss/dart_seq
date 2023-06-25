import 'package:dart_seq/src/seq_client.dart';
import 'package:dart_seq/src/seq_context.dart';
import 'package:dart_seq/src/seq_event.dart';
import 'package:dart_seq/src/seq_log_level.dart';
import 'package:dart_seq/src/seq_logger_configuration.dart';

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

  final SeqClient client;
  final SeqLoggerConfiguration configuration;
  late final Map<String, dynamic>? globalContext;

  final List<SeqEvent> _events = [];

  String? minimumLogLevel;

  SeqLogger({required this.configuration, required this.client}) {
    if (configuration.globalContext != null) {
      globalContext = configuration.globalContext;
    } else {
      globalContext = null;
    }

    minimumLogLevel = configuration.minimumLogLevel;
  }

  Future<void> send(Iterable<SeqEvent> events) async {
    events.map(addContext).where(shouldLog).forEach(_events.add);

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

  bool shouldFlush() => _events.length >= configuration.backlogLimit;

  Future<void> flush() async => client.sendEvents(_events);

  void log(SeqLogLevel level, String message, [SeqContext? context]) {
    if (context != null && context.isEmpty) {
      context = null;
    }

    final event = SeqEvent.now(message, level.value, null, null, context);

    send([event]);
  }
}
