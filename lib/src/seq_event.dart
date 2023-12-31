import 'dart:convert';

import 'package:dart_seq/src/seq_context.dart';
import 'package:dart_seq/src/seq_log_level.dart';

/// This class represents a single Seq event. It includes metadata like the
/// timestamp and also the actual message and context.
class SeqEvent {
  /// Creates an event with the given [message], [level], [id], [exception],
  /// and [context]. The timestamp is set to [DateTime.now()] and values
  /// included in [context] are rendered to representations suitable for JSON
  /// encoding.
  static SeqEvent now(
    String? message, [
    String? level,
    int? id,
    Object? exception,
    SeqContext? context,
  ]) {
    final time = DateTime.now();
    final renderings =
        context?.map((key, value) => MapEntry(key, _renderValue(value)));
    final m = renderings == null ? message : null;
    final mt = renderings == null ? null : message;

    return SeqEvent(time, m, mt, level, exception, id, renderings, context);
  }

  static dynamic _renderValue(dynamic value) {
    if (value is num || value is bool || value is String || null == value) {
      return value;
    }

    return jsonEncode(value);
  }

  /// Creates a [SeqLogLevel.verbose] event.
  static SeqEvent verbose(String message, [SeqContext? context]) {
    return SeqEvent.now(
        message, SeqLogLevel.verbose.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.debug] event.
  static SeqEvent debug(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.debug.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.information] event.
  static SeqEvent info(String message, [SeqContext? context]) {
    return SeqEvent.now(
        message, SeqLogLevel.information.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.warning] event.
  static SeqEvent warning(String message, [SeqContext? context]) {
    return SeqEvent.now(
        message, SeqLogLevel.warning.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.error] event.
  static SeqEvent error(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.error.value, null, null, context);
  }

  /// Creates a [SeqLogLevel.fatal] event.
  static SeqEvent fatal(String message, [SeqContext? context]) {
    return SeqEvent.now(message, SeqLogLevel.fatal.value, null, null, context);
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

  /// Creates an event with the given [timestamp], [message]/[messageTemplate],
  /// [level], [exception], [id], [renderings], and [context].
  SeqEvent(
    this.timestamp,
    this.message,
    this.messageTemplate,
    this.level,
    this.exception,
    this.id,
    this.renderings,
    this.context,
  );

  /// Returns a copy of this event with the given [context] merged into the
  /// existing context, if any.
  SeqEvent withAddedContext(SeqContext? context) {
    if (context == null) return this;
    final newContext = {
      ...?this.context,
      ...context,
    };

    return SeqEvent(
      timestamp,
      message,
      messageTemplate,
      level,
      exception,
      id,
      renderings,
      newContext,
    );
  }

  /// Used by [jsonEncode], alias for [toMap].
  Map<String, dynamic> toJson() => toMap();

  /// Returns this event as a map compatible with the GELF logging format.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
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
      data['@x'] = Error.safeToString(exception);
    }

    if (id != null) {
      data['@i'] = id;
    }

    if (renderings?.isNotEmpty ?? false) {
      data['@r'] = renderings;
    }

    if (context != null) {
      for (var e in context!.entries) {
        var key = e.key;
        if (key[0] == "@") {
          key = "@$key";
        }

        data[key] = e.value;
      }
    }

    return data;
  }

  factory SeqEvent.fromMap(Map<String, dynamic> map) {
    DateTime? timestamp;
    String? message;
    String? messageTemplate;
    String? level;
    Object? exception;
    int? id;
    Map<String, dynamic>? renderings;
    SeqContext? context;

    for (final e in map.entries) {
      if (e.key == "@t") {
        timestamp = DateTime.parse(e.value);
      } else if (e.key == "@m") {
        message = e.value;
      } else if (e.key == "@mt") {
        messageTemplate = e.value;
      } else if (e.key == "@l") {
        level = e.value;
      } else if (e.key == "@x") {
        exception = e.value;
      } else if (e.key == "@r") {
        renderings = e.value;
      } else if (e.key == "@i") {
        id = int.parse(e.value);
      } else {
        context ??= <String, dynamic>{};

        context[e.key] = e.value;
      }
    }

    timestamp ??= DateTime.now();

    return SeqEvent(
      timestamp,
      message,
      messageTemplate,
      level,
      exception,
      id,
      renderings,
      context,
    );
  }
}
