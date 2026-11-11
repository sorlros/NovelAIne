import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/play_models.dart';
import 'package:frontend/data/models/story_model.dart';
import 'package:frontend/presentation/widgets/play_choices_panel.dart';

PlayStatus play({
  int beatSeq = 2,
  String? question = '문을 열 것인가?',
  bool preparing = false,
  bool finished = false,
  List<String> callbacks = const [],
}) {
  return PlayStatus.fromJson({
    'beat_seq': beatSeq,
    'question': question,
    'choices': [
      {'id': 'c1', 'label': '문을 연다', 'lasting': true},
      {'id': 'c2', 'label': '돌아선다', 'lasting': false},
    ],
    'preparing': preparing,
    'finished': finished,
    'present_characters': ['카엘'],
    'callbacks': callbacks,
  });
}

Future<List<String>> pumpPanel(
  WidgetTester tester,
  PlayStatus? status, {
  bool busy = false,
  bool loadFailed = false,
}) async {
  final events = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlayChoicesPanel(
          status: status,
          busy: busy,
          loadFailed: loadFailed,
          onChoose: (choice) => events.add('choose:${choice.id}'),
          onWrite: (text) => events.add('write:$text'),
          onUndo: () => events.add('undo'),
          onReload: () => events.add('reload'),
        ),
      ),
    ),
  );
  return events;
}

void main() {
  group('models', () {
    test('play status reads the server payload', () {
      final status = play(question: '');
      expect(status.question, isNull);
      expect(status.choices.map((c) => c.lasting), [true, false]);
      expect(status.presentCharacters, ['카엘']);
      expect(status.canUndo, isTrue);
      expect(play(beatSeq: 1).canUndo, isFalse);
    });

    test('generation status tells the step in progress', () {
      GenerationStatus at(String step) =>
          GenerationStatus.fromJson({'status': 'running', 'step': step});
      expect(at('none').stepIndex, 0);
      expect(at('spine').stepIndex, 2);
      expect(at('opening').stepIndex, GenerationStatus.steps.length);
      expect(at('world').label, contains('줄기'));
      expect(
        GenerationStatus.fromJson({
          'status': 'running',
          'title': '망각의 세금',
        }).title,
        '망각의 세금',
      );
      expect(
        GenerationStatus.fromJson({
          'status': 'failed',
          'step': 'world',
        }).isFailed,
        isTrue,
      );
    });

    test('stories without a mode are legacy', () {
      StoryModel story(Map<String, dynamic> extra) => StoryModel.fromJson({
        'id': 's1',
        'title': '제목',
        'genre': 'fantasy',
        'status': 'generating',
        'created_at': '2026-11-10T00:00:00Z',
        ...extra,
      });
      expect(story({}).isSkeleton, isFalse);
      expect(story({'mode': 'skeleton'}).isSkeleton, isTrue);
      expect(story({}).isGenerating, isTrue);
      expect(story({'status': 'active'}).isGenerating, isFalse);
    });
  });

  group('choices panel', () {
    testWidgets('shows the question and choices, marks lasting ones', (
      tester,
    ) async {
      final events = await pumpPanel(tester, play(callbacks: ['약속을 지켰다']));
      expect(find.text('문을 열 것인가?'), findsOneWidget);
      expect(find.text('기억됩니다'), findsOneWidget);
      expect(find.text('당신의 선택: 약속을 지켰다'), findsOneWidget);

      await tester.tap(find.text('돌아선다'));
      await tester.tap(find.text('직전 선택 되돌리기'));
      expect(events, ['choose:c2', 'undo']);
    });

    testWidgets('sends the reader\'s own action, trimmed, and not when empty', (
      tester,
    ) async {
      final events = await pumpPanel(tester, play());
      await tester.tap(find.text('직접 입력'));
      await tester.pump();
      await tester.tap(find.byTooltip('보내기'));
      expect(events, isEmpty);

      await tester.enterText(find.byType(TextField), '  세라를 붙잡는다 ');
      await tester.tap(find.byTooltip('보내기'));
      await tester.pump();
      expect(events, ['write:세라를 붙잡는다']);
      expect(find.byType(TextField), findsNothing); // back to the choices
    });

    testWidgets('hides choices and undo while a scene is being written', (
      tester,
    ) async {
      await pumpPanel(tester, play(), busy: true);
      expect(find.text('문을 연다'), findsNothing);
      expect(find.text('직접 입력'), findsNothing);
      expect(find.text('직전 선택 되돌리기'), findsNothing);
    });

    testWidgets('says when the next part is being prepared', (tester) async {
      await pumpPanel(tester, play(preparing: true));
      expect(find.text('다음 이야기를 준비하고 있습니다...'), findsOneWidget);
      expect(find.text('문을 연다'), findsNothing);
    });

    testWidgets('says when the story has ended', (tester) async {
      await pumpPanel(tester, play(finished: true));
      expect(find.text('이야기가 끝났습니다.'), findsOneWidget);
      expect(find.text('문을 연다'), findsNothing);
    });

    testWidgets('offers to reload after a failed request', (tester) async {
      final events = await pumpPanel(tester, null, loadFailed: true);
      await tester.tap(find.text('다시 불러오기'));
      expect(events, ['reload']);
    });
  });
}
