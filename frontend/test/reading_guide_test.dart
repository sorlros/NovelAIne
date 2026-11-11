import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/reading_guide.dart';

void main() {
  final first = GlobalKey();
  final missing = GlobalKey();
  final last = GlobalKey();

  Future<List<String>> pumpGuide(WidgetTester tester) async {
    final done = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  SizedBox(key: first, width: 100, height: 40),
                  const SizedBox(height: 300),
                  SizedBox(key: last, width: 100, height: 40),
                ],
              ),
              Positioned.fill(
                child: ReadingGuide(
                  steps: [
                    GuideStep(target: first, text: '첫 안내'),
                    GuideStep(target: missing, text: '없는 대상'),
                    GuideStep(target: last, text: '마지막 안내'),
                  ],
                  onDone: () => done.add('done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return done;
  }

  testWidgets(
    'guide walks the steps, skipping a target that is not on screen',
    (tester) async {
      final done = await pumpGuide(tester);
      expect(find.text('첫 안내'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('없는 대상'), findsNothing);
      expect(find.text('마지막 안내'), findsOneWidget);
      expect(find.text('건너뛰기'), findsNothing);

      await tester.tap(find.text('시작하기'));
      expect(done, ['done']);
    },
  );

  testWidgets('skipping ends the guide at once', (tester) async {
    final done = await pumpGuide(tester);
    await tester.tap(find.text('건너뛰기'));
    expect(done, ['done']);
  });
}
