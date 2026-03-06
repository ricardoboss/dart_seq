import 'package:dart_seq/dart_seq.dart';
import 'package:test/test.dart';

void main() {
  group('SeqLogLevel', () {
    test('verbose has correct value', () {
      expect(SeqLogLevel.verbose.value, 'Verbose');
    });

    test('debug has correct value', () {
      expect(SeqLogLevel.debug.value, 'Debug');
    });

    test('information has correct value', () {
      expect(SeqLogLevel.information.value, 'Information');
    });

    test('warning has correct value', () {
      expect(SeqLogLevel.warning.value, 'Warning');
    });

    test('error has correct value', () {
      expect(SeqLogLevel.error.value, 'Error');
    });

    test('fatal has correct value', () {
      expect(SeqLogLevel.fatal.value, 'Fatal');
    });

    test('has exactly 6 values', () {
      expect(SeqLogLevel.values.length, 6);
    });
  });
}
