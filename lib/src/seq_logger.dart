import 'package:dart_seq/dart_seq.dart';

/// Callback invoked when [SeqLogger.flush] encounters send failures.
///
/// Receives per-event [results] indicating which events succeeded or failed,
/// and the [error] (the original exception for total failures, or a
/// descriptive [SeqClientException] for partial failures).
///
/// Return the events that should be re-queued in cache for retry.
/// Return an empty list to drop all failed events.
///
/// ## Default behavior (when not set)
///
/// - **Partial failure** (results returned): events with
///   [SeqEventResult.isPermanent] `true` are dropped (e.g. HTTP 400 -
///   the event is malformed and retrying would produce the same rejection).
///   Transient failures (`isPermanent: false`) are re-queued automatically.
/// - **Total failure** (exception thrown): all events stay in cache (they
///   were never sent).
///
/// ## When to provide a custom handler
///
/// Provide a custom handler when you need to:
/// - Log or report individual event failures
/// - Distinguish between error types beyond permanent/transient
///
/// See [SeqLogger.onFlushError] for a recommended implementation example.
typedef FlushErrorHandler =
    Future<List<SeqEvent>> Function(
      Iterable<SeqEventResult> results,
      Object error,
    );

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
    this.onFlushError,
    this.throwOnError = false,
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

  /// Optional callback invoked when [flush] encounters send failures.
  ///
  /// See [FlushErrorHandler] for full documentation and default behavior.
  ///
  /// ## Recommended implementation
  ///
  /// ```dart
  /// onFlushError: (results, error) async {
  ///   final toRetry = <SeqEvent>[];
  ///
  ///   for (final r in results.where((r) => !r.isSuccess)) {
  ///     if (r.isPermanent) {
  ///       // Event is malformed - retrying would fail again.
  ///       log('Dropping permanently rejected event: ${r.error}');
  ///       continue;
  ///     }
  ///     // Transient failure (network, server overload) - retry.
  ///     toRetry.add(r.event);
  ///   }
  ///
  ///   return toRetry;
  /// }
  /// ```
  final FlushErrorHandler? onFlushError;

  /// When `false` (default), exceptions during [flush] are caught and
  /// reported via [onDiagnosticLog]. When `true`, they propagate to caller.
  final bool throwOnError;

  /// The minimum log level that should be logged.
  String? minimumLogLevel;

  /// Sends an event to Seq.
  ///
  /// Checks [shouldLog] and [shouldFlush] before sending the event.
  Future<void> send(SeqEvent event) async {
    if (!shouldLog(event)) {
      return;
    }

    final contextualizedEvent = addContext(event);

    await cache.record(contextualizedEvent);

    if (autoFlush && shouldFlush()) {
      if (throwOnError) {
        await flush();
      } else {
        try {
          await flush();
        } on Exception catch (e) {
          diagnosticLog(SeqLogLevel.error, 'Auto-flush failed', e);
        }
      }
    }
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
  bool shouldFlush() => !_flushing && cache.count >= backlogLimit;

  /// Whether the logger is currently flushing events.
  bool _flushing = false;

  /// Batch size for the next flush. Starts at [backlogLimit] and halves on
  /// non-retryable errors to probe for a working batch size. Resets to
  /// [backlogLimit] after a successful send.
  late int _nextFlushBatchSize = backlogLimit;

  /// Flushes at most [backlogLimit] events in the cache to Seq and updates the
  /// minimum log level based on the response from Seq.
  Future<void> flush() async {
    if (_flushing) {
      return;
    }

    try {
      _flushing = true;

      diagnosticLog(SeqLogLevel.verbose, 'Flushing events');

      final eventsToBeSent = await cache.peek(_nextFlushBatchSize).toList();

      try {
        final results = await client.sendEvents(eventsToBeSent);

        // Path A: sendEvents returned results (batch succeeded or partial)
        await cache.remove(eventsToBeSent.length);
        _nextFlushBatchSize = backlogLimit;

        final failed = results.where((r) => !r.isSuccess);

        if (failed.isNotEmpty) {
          if (onFlushError case final handler?) {
            final error = SeqClientException(
              '${failed.length} of ${results.length} events failed',
            );
            final eventsToKeep = await handler(results, error);
            for (final event in eventsToKeep) {
              await cache.record(event);
            }
          } else {
            // Default: re-queue transient failures, drop permanent ones.
            // Re-queued events are appended to the end of the cache (not
            // inserted at their original position). This is fine because
            // each event carries its own @t timestamp and Seq handles
            // out-of-order events correctly.
            for (final r in failed) {
              if (r.isPermanent) {
                diagnosticLog(
                  SeqLogLevel.warning,
                  'Dropping permanently rejected event: {Message}',
                  r.error is Exception ? r.error! as Exception : null,
                  {'Message': r.event.message},
                );
              } else {
                await cache.record(r.event);
              }
            }
          }
        }

        _updateMinimumLogLevel();
      } on Exception catch (e) {
        // Path B: sendEvents threw (total failure - network/auth/413)
        // Events stay in cache by default (they were never sent).
        diagnosticLog(
          SeqLogLevel.error,
          'Failed to send {EventCount} events',
          e,
          {'EventCount': eventsToBeSent.length},
        );

        if (onFlushError case final handler?) {
          final syntheticResults = eventsToBeSent.map(
            (event) => SeqEventResult.failure(event, e),
          );
          await cache.remove(eventsToBeSent.length);
          final eventsToKeep = await handler(syntheticResults, e);
          for (final event in eventsToKeep) {
            await cache.record(event);
          }
        } else if (e is SeqClientException && !e.isRetryable) {
          // Non-retryable error (e.g. 413 Payload Too Large, 400 Bad
          // Request). Retrying the same batch will produce the same error.
          if (eventsToBeSent.length == 1) {
            // Single event is too large - drop it.
            await cache.remove(1);
            diagnosticLog(
              SeqLogLevel.warning,
              'Dropping non-retryable event: {Message}',
              e,
              {'Message': eventsToBeSent.first.message},
            );
            _nextFlushBatchSize = backlogLimit;
          } else {
            // Halve the batch size for the next flush attempt. Events stay
            // in cache - only the peek window shrinks.
            _nextFlushBatchSize = (eventsToBeSent.length ~/ 2).clamp(
              1,
              backlogLimit,
            );
            diagnosticLog(
              SeqLogLevel.warning,
              'Reducing batch size from {OldSize} to {NewSize} '
              'after non-retryable error',
              e,
              {
                'OldSize': eventsToBeSent.length,
                'NewSize': _nextFlushBatchSize,
              },
            );
          }
        }

        if (throwOnError && onFlushError == null) {
          rethrow;
        }
      }
    } on Exception catch (e) {
      if (throwOnError) {
        rethrow;
      }
      diagnosticLog(SeqLogLevel.error, 'Flush failed unexpectedly', e);
    } finally {
      _flushing = false;
    }
  }

  void _updateMinimumLogLevel() {
    final newLogLevel = client.minimumLevelAccepted;
    if (minimumLogLevel == newLogLevel) {
      return;
    }

    diagnosticLog(
      SeqLogLevel.verbose,
      'Accepted new log level {MinimumLogLevel}',
      null,
      {'MinimumLogLevel': newLogLevel},
    );

    minimumLogLevel = newLogLevel;
  }

  /// Records an event for sending to Seq.
  ///
  /// The [level] and [message] are required. All other parameters are optional.
  ///
  /// The [exception] is serialized into the CLEF `@x` field.
  ///
  /// The [context] is a map of additional properties attached to the event.
  ///
  /// The distributed tracing parameters follow the OpenTelemetry specification
  /// and are mapped to Seq's CLEF extensions:
  ///
  /// - [traceId] (`@tr`) - the distributed trace identifier, a 32-character
  ///   lowercase hex string. See [W3C Trace Context](https://www.w3.org/TR/trace-context/#trace-id).
  /// - [spanId] (`@sp`) - the span identifier, a 16-character lowercase hex
  ///   string uniquely identifying this unit of work within a trace.
  ///   See [W3C Trace Context](https://www.w3.org/TR/trace-context/#parent-id).
  /// - [parentSpanId] (`@ps`) - the span ID of the caller/parent span.
  /// - [spanStart] (`@st`) - the timestamp when the span started. Used with
  ///   the event timestamp to compute span duration.
  /// - [scope] (`@sc`) - the instrumentation scope (e.g. library or module
  ///   name) that produced the event.
  /// - [resourceAttributes] (`@ra`) - a map of resource attributes describing
  ///   the entity producing telemetry (e.g. service name, version, host).
  ///   See [OpenTelemetry Resource SDK](https://opentelemetry.io/docs/specs/otel/resource/sdk/).
  /// - [spanKind] (`@sk`) - the kind of span: `client`, `server`, `producer`,
  ///   `consumer`, or `internal`.
  ///   See [OpenTelemetry SpanKind](https://opentelemetry.io/docs/specs/otel/trace/api/#spankind).
  ///
  /// For more details on Seq's CLEF format, see
  /// [Seq CLEF documentation](https://docs.datalust.co/docs/the-compact-log-event-format).
  Future<void> log(
    SeqLogLevel level,
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) async {
    var actualContext = context;

    if (context != null && context.isEmpty) {
      actualContext = null;
    }

    final event = SeqEvent.now(
      message,
      level.value,
      null,
      exception,
      actualContext,
      traceId,
      spanId,
      parentSpanId,
      spanStart,
      scope,
      resourceAttributes,
      spanKind,
    );

    await send(event);
  }

  /// Records a verbose event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> verbose(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.verbose,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );

  /// Records a debug event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> debug(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.debug,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );

  /// Records an information event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> info(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.information,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );

  /// Records a warning event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> warning(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.warning,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );

  /// Records an error event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> error(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.error,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );

  /// Records a fatal event for sending to Seq.
  ///
  /// See [log] for parameter documentation.
  Future<void> fatal(
    String message, {
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  }) => log(
    SeqLogLevel.fatal,
    message,
    exception: exception,
    context: context,
    traceId: traceId,
    spanId: spanId,
    parentSpanId: parentSpanId,
    spanStart: spanStart,
    scope: scope,
    resourceAttributes: resourceAttributes,
    spanKind: spanKind,
  );
}
