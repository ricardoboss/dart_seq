import 'package:dart_seq/dart_seq.dart';

Future<void> main() async {
  final logger = SeqLogger.http(
    host: 'http://localhost:5341',
    globalContext: {
      'App': 'Example',
    },
  );

  await logger.log(
    SeqLogLevel.information,
    'test, logged at: {Timestamp}',
    null,
    {
      'Timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  );

  await logger.flush();
}
