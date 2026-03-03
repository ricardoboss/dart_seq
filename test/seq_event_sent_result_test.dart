import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqEventSentResult', () {
    test('stores event, error, and isSuccess', () {
      final event = SeqEvent.info('test');
      final error = Exception('something went wrong');

      final result = SeqEventSentResult(
        event: event,
        error: error,
        isSuccess: false,
      );

      expect(result.event, same(event));
      expect(result.error, same(error));
      expect(result.isSuccess, isFalse);
      expect(result.isPermanent, isFalse);
    });

    test('success factory creates successful result', () {
      final event = SeqEvent.info('test');

      final result = SeqEventSentResult.success(event);

      expect(result.event, same(event));
      expect(result.error, isNull);
      expect(result.isSuccess, isTrue);
      expect(result.isPermanent, isFalse);
    });

    test('failure factory creates failed result with error', () {
      final event = SeqEvent.info('test');
      final error = Exception('bad event');

      final result = SeqEventSentResult.failure(event, error);

      expect(result.event, same(event));
      expect(result.error, same(error));
      expect(result.isSuccess, isFalse);
      expect(result.isPermanent, isFalse);
    });

    test('failure factory supports isPermanent flag', () {
      final event = SeqEvent.info('test');
      final error = Exception('malformed');

      final result = SeqEventSentResult.failure(
        event,
        error,
        isPermanent: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.isPermanent, isTrue);
    });
  });
}
