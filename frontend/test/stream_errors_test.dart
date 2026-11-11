import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/services/api_service.dart';

Future<String> read(List<String> chunks) =>
    readStreamErrors(Stream.fromIterable(chunks)).join();

void main() {
  test('plain text passes through, brackets included', () async {
    expect(await read(['숲길에 ', '바람이 [불었다', '].']), '숲길에 바람이 [불었다].');
  });

  test('a marker split across chunks is still an error', () async {
    await expectLater(
      read(['본문\n[STREAM_', 'ERROR:일시적인 ', '문제입니다]']),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', '일시적인 문제입니다'),
      ),
    );
  });

  test('a marker cut off at the end of the stream is still an error', () async {
    await expectLater(
      read(['본문\n[STREAM_ERROR:끝나지 않은']),
      throwsA(isA<ApiException>()),
    );
  });
}
