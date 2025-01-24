import 'dart:async';

import 'package:dart_seq/dart_seq.dart';
import 'package:synchronized/synchronized.dart';

/// The base class for logging events to Seq.
class SeqLogger {
  /// Creates a new instance of [SeqLogger].
  SeqLogger({
    required this.client,
    required this.cache,
    this.backlogLimit = 50,
    this.globalContext,
    this.minimumLogLevel,
    this.autoFlush = true,
  }) : assert(backlogLimit >= 0, 'backlogLimit must be >= 0');

  /// Compares two log levels.
  static int compareLevels(String? a, String? b) {
    if (a == null && b == null) {
      return 0;
    }

    if (a == null) {
      return -1;
    }

    if (b == null) {
      return 1;
    }

    final aLevel = levelToInt(a);
    final bLevel = levelToInt(b);

    return aLevel.compareTo(bLevel);
  }

  /// Converts a log level to an integer.
  ///
  /// The higher the integer, the more severe the log level.
  /// `-1` is returned if the log level is not recognized.
  static int levelToInt(String level) {
    return switch (level) {
      'Verbose' => 0,
      'Debug' => 1,
      'Information' => 2,
      'Warning' => 3,
      'Error' => 4,
      'Fatal' => 5,
      _ => -1,
    };
  }

  /// Set this to a function that will be called when a diagnostic log is
  /// generated.
  ///
  /// This is useful for debugging the [SeqLogger] class itself.
  static void Function(SeqEvent event)? onDiagnosticLog;

  /// Logs a diagnostic message.
  static void diagnosticLog(
    SeqLogLevel level,
    String message, [
    Exception? exception,
    SeqContext? context,
  ]) {
    final event = SeqEvent.now(message, level.name, 0, exception, context);

    onDiagnosticLog?.call(event);
  }

  /// The client used to send events to Seq.
  final SeqClient client;

  /// The cache used to store events before they are sent to Seq.
  final SeqCache cache;

  /// The maximum number of events that should be stored in the cache before
  /// automatically flushing them to Seq.
  final int backlogLimit;

  /// The global context that should be added to every event.
  final SeqContext? globalContext;

  /// Whether the logger should automatically flush the events to Seq when the
  /// backlog limit is reached.
  final bool autoFlush;

  /// The minimum log level that should be logged.
  String? minimumLogLevel;

  /// A lock used to prevent multiple flushes from happening at the same time.
  late final Lock _flushLock = Lock();

  /// Sends an event to Seq.
  ///
  /// Checks [shouldLog] and [shouldFlush] before sending the event.
  Future<void> send(SeqEvent event) async {
    if (!shouldLog(event)) {
      return;
    }

    final contextualizedEvent = addContext(event);

    await cache.record(contextualizedEvent);

    unawaited(
      _flushLock.synchronized(() async {
        if (autoFlush && shouldFlush()) {
          await flush();
        }
      }),
    );
  }

  /// Adds the global context to an event.
  SeqEvent addContext(SeqEvent event) {
    return event.withAddedContext(globalContext);
  }

  /// Checks if an event should be logged based on the minimum log level.
  bool shouldLog(SeqEvent event) {
    return minimumLogLevel == null ||
        compareLevels(minimumLogLevel, event.level) <= 0;
  }

  /// Checks if the cache should be flushed based on the backlog limit.
  bool shouldFlush() => cache.count >= backlogLimit;

  /// Flushes at most [backlogLimit] events in the cache to Seq and updates the
  /// minimum log level based on the response from Seq.
  Future<void> flush() async {
    diagnosticLog(SeqLogLevel.verbose, 'Flushing events');

    final eventsToBeSent = await cache.peek(backlogLimit).toList();

    await client.sendEvents(eventsToBeSent);

    await cache.remove(eventsToBeSent.length);

    final newLogLevel = client.minimumLevelAccepted;
    if (minimumLogLevel != newLogLevel) {
      diagnosticLog(
        SeqLogLevel.verbose,
        'Accepted new log level {MinimumLogLevel}',
        null,
        {'MinimumLogLevel': newLogLevel},
      );

      minimumLogLevel = newLogLevel;
    }
  }

  /// Records an event for sending to Seq.
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

  /// Records a verbose event for sending to Seq.
  Future<void> verbose(String message, [SeqContext? context]) =>
      log(SeqLogLevel.verbose, message, null, context);

  /// Records a debug event for sending to Seq.
  Future<void> debug(String message, [SeqContext? context]) =>
      log(SeqLogLevel.debug, message, null, context);

  /// Records an information event for sending to Seq.
  Future<void> info(String message, [SeqContext? context]) =>
      log(SeqLogLevel.information, message, null, context);

  /// Records a warning event for sending to Seq.
  Future<void> warning(String message, [SeqContext? context]) =>
      log(SeqLogLevel.warning, message, null, context);

  /// Records an error event for sending to Seq.
  Future<void> error(
    String message, [
    Object? exception,
    SeqContext? context,
  ]) =>
      log(SeqLogLevel.error, message, exception, context);

  /// Records a fatal event for sending to Seq.
  Future<void> fatal(
    String message, [
    Object? exception,
    SeqContext? context,
  ]) =>
      log(SeqLogLevel.fatal, message, exception, context);
}
