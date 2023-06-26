import 'package:dart_seq/src/seq_event.dart';

abstract class SeqClient {
  Future<void> sendEvents(Stream<SeqEvent> events);

  String? get minimumLevelAccepted;
}
