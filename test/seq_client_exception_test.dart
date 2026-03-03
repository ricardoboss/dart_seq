import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqClientException', () {
    test('stores message', () {
      final exception = SeqClientException('something went wrong');

      expect(exception.message, 'something went wrong');
      expect(exception.innerException, isNull);
      expect(exception.innerStackTrace, isNull);
    });

    test('stores inner exception and stack trace', () {
      final inner = Exception('root cause');
      final stackTrace = StackTrace.current;

      final exception = SeqClientException(
        'wrapper',
        inner,
        stackTrace,
      );

      expect(exception.message, 'wrapper');
      expect(exception.innerException, inner);
      expect(exception.innerStackTrace, stackTrace);
    });

    test('toString includes message', () {
      final exception = SeqClientException('test error');

      expect(exception.toString(), contains('SeqClientException'));
      expect(exception.toString(), contains('test error'));
    });

    test('toString includes inner exception when present', () {
      final inner = Exception('root');
      final exception = SeqClientException('wrapper', inner);

      final str = exception.toString();

      expect(str, contains('wrapper'));
      expect(str, contains('innerException'));
      expect(str, contains('root'));
    });

    test('toString excludes inner exception when null', () {
      final exception = SeqClientException('only message');

      expect(exception.toString(), isNot(contains('innerException')));
    });

    test('implements Exception', () {
      final exception = SeqClientException('msg');

      expect(exception, isA<Exception>());
    });
  });
}
