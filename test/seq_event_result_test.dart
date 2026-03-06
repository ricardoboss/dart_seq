import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqEventResult', () {
    test('failure factory stores event, error, and isSuccess', () {
      final event = SeqEvent.info('test');
      final error = Exception('something went wrong');

      final result = SeqEventResult.failure(event, error);

      expect(result.event, same(event));
      expect(result.error, same(error));
      expect(result.isSuccess, isFalse);
      expect(result.isPermanent, isFalse);
    });

    test('success factory creates successful result', () {
      final event = SeqEvent.info('test');

      final result = SeqEventResult.success(event);

      expect(result.event, same(event));
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
      expect(result.isPermanent, isFalse);
    });

    test('failure factory supports isPermanent flag', () {
      final event = SeqEvent.info('test');
      final error = Exception('malformed');

      final result = SeqEventResult.failure(event, error, isPermanent: true);

      expect(result.isSuccess, isFalse);
      expect(result.isPermanent, isTrue);
    });
  });
}
