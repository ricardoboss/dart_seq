import 'dart:io';

import 'package:dart_seq/dart_seq.dart';

void main() {
  final logger = SeqLogger.http(
    host: 'http://localhost:5341',
    globalContext: {
      'Environment': Platform.environment,
    },
  );

  logger.log(SeqLogLevel.information, 'test, dart: {Dart}', {
    'Dart': Platform.version,
  });

  logger.flush();
}
