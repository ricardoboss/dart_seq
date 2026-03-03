import 'dart:convert';

import 'package:dart_seq/src/seq_context.dart';
import 'package:dart_seq/src/seq_log_level.dart';

/// Known Seq CLEF keys that should not be double-escaped in context.
const _knownSeqKeys = {
  '@t',
  '@m',
  '@mt',
  '@l',
  '@x',
  '@i',
  '@r',
  '@tr',
  '@sp',
  '@ps',
  '@st',
  '@sc',
  '@ra',
  '@sk',
};

/// This class represents a single Seq event. It includes metadata like the
/// timestamp and also the actual message and context.
class SeqEvent {
  /// Creates an event with the given fields.
  SeqEvent({
    required this.timestamp,
    this.message,
    this.messageTemplate,
    this.level,
    this.exception,
    this.id,
    this.renderings,
    this.context,
    this.traceId,
    this.spanId,
    this.parentSpanId,
    this.spanStart,
    this.scope,
    this.resourceAttributes,
    this.spanKind,
  });

  /// Creates an event from the given [map]. The map should be compatible with
  /// the CLEF logging format. The timestamp is parsed from the map, and the
  /// message, message template, level, exception, and id are read from the map
  /// as strings. The renderings are read as a map of strings, and the context
  /// is read as a map of strings to dynamic.
  /// If the map does not contain a timestamp, the current time is used.
  factory SeqEvent.fromMap(Map<String, dynamic> map) {
    DateTime? timestamp;
    String? message;
    String? messageTemplate;
    String? level;
    Object? exception;
    int? id;
    Map<String, dynamic>? renderings;
    SeqContext? context;
    String? traceId;
    String? spanId;
    String? parentSpanId;
    DateTime? spanStart;
    String? scope;
    Map<String, dynamic>? resourceAttributes;
    String? spanKind;

    void addToContext(MapEntry<String, dynamic> entry) {
      context ??= <String, dynamic>{};

      context![entry.key] = entry.value;
    }

    for (final e in map.entries) {
      if (e.value is String) {
        final value = e.value as String;

        if (e.key == '@t') {
          timestamp = DateTime.parse(value);
        } else if (e.key == '@m') {
          message = value;
        } else if (e.key == '@mt') {
          messageTemplate = value;
        } else if (e.key == '@l') {
          level = value;
        } else if (e.key == '@i') {
          id = int.parse(value);
        } else if (e.key == '@x') {
          exception = e.value;
        } else if (e.key == '@tr') {
          traceId = value;
        } else if (e.key == '@sp') {
          spanId = value;
        } else if (e.key == '@ps') {
          parentSpanId = value;
        } else if (e.key == '@st') {
          spanStart = DateTime.parse(value);
        } else if (e.key == '@sc') {
          scope = value;
        } else if (e.key == '@sk') {
          spanKind = value;
        } else {
          addToContext(e);
        }
      } else if (e.value is Map && e.key == '@r') {
        renderings = e.value as Map<String, dynamic>;
      } else if (e.value is Map && e.key == '@ra') {
        resourceAttributes = e.value as Map<String, dynamic>;
      } else {
        if (e.key == '@x') {
          exception = e.value;
        } else {
          addToContext(e);
        }
      }
    }

    timestamp ??= DateTime.now();

    return SeqEvent(
      timestamp: timestamp,
      message: message,
      messageTemplate: messageTemplate,
      level: level,
      exception: exception,
      id: id,
      renderings: renderings,
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

  /// Creates an event with the given [message], [level], [id], [exception],
  /// and [context]. The timestamp is set to [DateTime.now()] and values
  /// included in [context] are rendered to representations suitable for JSON
  /// encoding.
  factory SeqEvent.now(
    String? message, [
    String? level,
    int? id,
    Object? exception,
    SeqContext? context,
    String? traceId,
    String? spanId,
    String? parentSpanId,
    DateTime? spanStart,
    String? scope,
    Map<String, dynamic>? resourceAttributes,
    String? spanKind,
  ]) {
    final time = DateTime.now();
    final renderings =
        context?.map((key, value) => MapEntry(key, _renderValue(value)));
    final m = renderings == null ? message : null;
    final mt = renderings == null ? null : message;

    return SeqEvent(
      timestamp: time,
      message: m,
      messageTemplate: mt,
      level: level,
      exception: exception,
      id: id,
      renderings: renderings,
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

  /// Creates a [SeqLogLevel.verbose] event.
  factory SeqEvent.verbose(String message, [SeqContext? context]) {
    return SeqEvent.now(
      message,
      SeqLogLevel.verbose.value,
      null,
      null,
      context,
    );
  }

  /// Creates a [SeqLogLevel.debug] event.
  factory SeqEvent.debug(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.debug.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.information] event.
  factory SeqEvent.info(String message, [SeqContext? context]) {
    return SeqEvent.now(
      message,
      SeqLogLevel.information.value,
      null,
      null,
      context,
    );
  }

  /// Creates a [SeqLogLevel.warning] event.
  factory SeqEvent.warning(String message, [SeqContext? context]) {
    return SeqEvent.now(
      message,
      SeqLogLevel.warning.value,
      null,
      null,
      context,
    );
  }

  /// Creates a [SeqLogLevel.error] event.
  factory SeqEvent.error(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.error.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.fatal] event.
  factory SeqEvent.fatal(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.fatal.value, null, null, context);
  }

  static dynamic _renderValue(dynamic value) {
    if (value is num || value is bool || value is String || null == value) {
      return value;
    }

    return jsonEncode(value);
  }

  /// The timestamp of the event.
  final DateTime timestamp;

  /// The message of the event. Either this or [messageTemplate] must be set.
  final String? message;

  /// The message template of the event. Either this or [message] must be set.
  /// Message templates include placeholder that will be replaced on the server.
  final String? messageTemplate;

  /// The level of the event. SHOULD be one of [SeqLogLevel].
  final String? level;

  /// The exception of the event.
  final Object? exception;

  /// A unique id for the event.
  final int? id;

  /// This map must have the exact same number of entries as there are
  /// placeholders included in the [messageTemplate]. Each key must correspond
  /// to one of the keys in [context] and their values should be representable
  /// in a string.
  final Map<String, dynamic>? renderings;

  /// Any context relevant for this event.
  final SeqContext? context;

  /// The trace ID for distributed tracing (@tr).
  final String? traceId;

  /// The span ID for distributed tracing (@sp).
  final String? spanId;

  /// The parent span ID for distributed tracing (@ps).
  final String? parentSpanId;

  /// The span start timestamp (@st).
  final DateTime? spanStart;

  /// The instrumentation scope (@sc).
  final String? scope;

  /// Resource attributes for OpenTelemetry integration (@ra).
  final Map<String, dynamic>? resourceAttributes;

  /// The span kind (@sk).
  final String? spanKind;

  /// Returns a copy of this event with the given [context] merged into the
  /// existing context, if any.
  SeqEvent withAddedContext(SeqContext? context) {
    if (context == null) {
      return this;
    }

    final newContext = {
      ...?this.context,
      ...context,
    };

    return SeqEvent(
      timestamp: timestamp,
      message: message,
      messageTemplate: messageTemplate,
      level: level,
      exception: exception,
      id: id,
      renderings: renderings,
      context: newContext,
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      spanStart: spanStart,
      scope: scope,
      resourceAttributes: resourceAttributes,
      spanKind: spanKind,
    );
  }

  /// Used by [jsonEncode], alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  /// Returns this event as a map compatible with the CLEF logging format.
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      '@t': timestamp.toUtc().toIso8601String(),
    };

    if (message != null) {
      data['@m'] = message;
    }

    if (messageTemplate != null) {
      data['@mt'] = messageTemplate;
    }

    if (level != null) {
      data['@l'] = level;
    }

    if (exception != null) {
      data['@x'] = exception.toString();
    }

    if (id != null) {
      data['@i'] = id;
    }

    if (renderings?.isNotEmpty ?? false) {
      data['@r'] = renderings;
    }

    if (traceId != null) {
      data['@tr'] = traceId;
    }
    if (spanId != null) {
      data['@sp'] = spanId;
    }
    if (parentSpanId != null) {
      data['@ps'] = parentSpanId;
    }
    if (spanStart != null) {
      data['@st'] = spanStart!.toUtc().toIso8601String();
    }
    if (scope != null) {
      data['@sc'] = scope;
    }
    if (resourceAttributes?.isNotEmpty ?? false) {
      data['@ra'] = resourceAttributes;
    }
    if (spanKind != null) {
      data['@sk'] = spanKind;
    }

    if (context != null) {
      for (final e in context!.entries) {
        var key = e.key;
        if (key[0] == '@' && !_knownSeqKeys.contains(key)) {
          key = '@$key';
        }

        data[key] = e.value;
      }
    }

    return data;
  }
}
