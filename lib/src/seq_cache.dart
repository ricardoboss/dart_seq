import 'package:dart_seq/dart_seq.dart';

abstract class SeqCache {
  int get count;

  Future<void> record(SeqEvent event);

  Stream<SeqEvent> take();
}
