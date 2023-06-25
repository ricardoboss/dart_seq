import 'dart:convert';

import 'package:dart_seq/src/seq_context.dart';
import 'package:dart_seq/src/seq_log_level.dart';

class SeqEvent {
  static SeqEvent now(String? message,
      [String? level, int? id, Object? exception, SeqContext? context]) {
    final time = DateTime.now();
    final renderings =
        context?.map((key, value) => MapEntry(key, _renderValue(value)));
    final m = renderings == null ? message : null;
    final mt = renderings == null ? null : message;

    return SeqEvent(time, m, mt, level, exception, id, renderings, context);
  }

  static dynamic _renderValue(dynamic value) {
    if (value is num || value is bool || null == value) {
      return value;
    }

    if (value is String) {
      return value;
    }

    return jsonEncode(value);
  }

  static SeqEvent verbose(String message, SeqContext? context) {
    return SeqEvent.now(
        message, SeqLogLevel.verbose.value, null, null, context);
  }

  static SeqEvent debug(String message, SeqContext? context) {
    return SeqEvent.now(message, SeqLogLevel.debug.value, null, null, context);
  }

  static SeqEvent info(String message, SeqContext? context) {
    return SeqEvent.now(
        message, SeqLogLevel.information.value, null, null, context);
  }

  static SeqEvent warning(String message, SeqContext? context) {
    return SeqEvent.now(
        message, SeqLogLevel.warning.value, null, null, context);
  }

  static SeqEvent error(String message, SeqContext? context) {
    return SeqEvent.now(message, SeqLogLevel.error.value, null, null, context);
  }

  static SeqEvent fatal(String message, SeqContext? context) {
    return SeqEvent.now(message, SeqLogLevel.fatal.value, null, null, context);
  }

  final DateTime timestamp;
  final String? message;
  final String? messageTemplate;
  final String? level;
  final Object? exception;
  final int? id;
  final Map<String, dynamic>? renderings;
  final SeqContext? context;

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

  Map<String, dynamic> toJson() {
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
}
