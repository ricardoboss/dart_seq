import 'package:dart_seq/src/seq_cache.dart';
import 'package:dart_seq/src/seq_event.dart';

class SeqInMemoryCache implements SeqCache {
  final List<SeqEvent> _events = <SeqEvent>[];

  @override
  Future<void> record(SeqEvent event) async {
    _events.add(event);
  }

  @override
  Stream<SeqEvent> peek(int count) async* {
    final max = count.clamp(0, this.count);

    for (int i = 0; i < max; i++) {
      yield _events.elementAt(i);
    }
  }

  @override
  int get count => _events.length;

  @override
  Future<void> remove(int count) async {
    final max = count.clamp(0, this.count);

    _events.removeRange(0, max);
  }
}
