import 'package:dart_seq/dart_seq.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'seq_logger_test.mocks.dart';

@GenerateMocks([SeqClient, SeqCache])
void main() {
  group('Seq Logger', () {
    test('Happy path', () async {
      // Arrange
      final client = MockSeqClient();
      final cache = MockSeqCache();

      when(cache.record(captureThat(isA<SeqEvent>()))).thenAnswer((_) async {});

      when(cache.count).thenReturn(1);

      when(cache.peek(1)).thenAnswer((_) async* {
        yield verify(
          cache.record(
            captureThat(
              predicate<SeqEvent>(
                (e) =>
                    e.message == 'test' &&
                    e.level == 'Information' &&
                    e.context != null &&
                    e.context!['app'] == 'test',
              ),
            ),
          ),
        ).captured.single as SeqEvent;
      });

      when(cache.remove(1)).thenAnswer((_) async {});

      when(client.sendEvents(any)).thenAnswer((_) async {});

      when(client.minimumLevelAccepted).thenReturn('information');

      // Act
      final logger = SeqLogger(
        client: client,
        cache: cache,
        backlogLimit: 1,
        globalContext: {
          'app': 'test',
        },
      );

      await logger.log(SeqLogLevel.information, 'test');

      // Assert
      expect(logger, isNotNull);
      expect(logger.minimumLogLevel, 'information');
    });
  });
}
