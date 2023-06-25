import 'dart:io';

import 'package:dart_seq/dart_seq.dart';

void main() {
  final httpConfig = SeqHttpClientConfiguration("http://localhost:5341");
  final httpClient = SeqHttpClient(httpConfig);

  const loggerConfig = SeqLoggerConfiguration();
  final logger = SeqLogger(configuration: loggerConfig, client: httpClient);

  logger.log(SeqLogLevel.information, "test, dart: {Dart}", {
    "Dart": Platform.version,
    "Environment": Platform.environment,
  });
  logger.flush();
}
