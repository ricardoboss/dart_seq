import 'package:dart_seq/src/seq_cache.dart';
import 'package:dart_seq/src/seq_event.dart';

class SeqInMemoryCache implements SeqCache {
  final List<SeqEvent> _events = <SeqEvent>[];

  @override
  Future<void> record(SeqEvent event) async {
    _events.add(event);
  }

  @override
  Stream<SeqEvent> take() async* {
    while (_events.isNotEmpty) {
      yield _events.removeAt(0);
    }
  }

  @override
  int get count => _events.length;
}
