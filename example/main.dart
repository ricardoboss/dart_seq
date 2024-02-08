import 'dart:io';

import 'package:dart_seq/dart_seq.dart';

Future<void> main() async {
  final logger = SeqLogger.http(
    host: 'http://localhost:5341',
    globalContext: {
      'Environment': Platform.environment,
    },
  );

  await logger.log(SeqLogLevel.information, 'test, dart: {Dart}', {
    'Dart': Platform.version,
  });

  await logger.flush();
}
