import 'package:material_ui/material_ui.dart';
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

  Future<void> pumpOne(WidgetTester tester, Widget target) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              target,
              Positioned.fill(
                child: ReadingGuide(
                  steps: [GuideStep(target: last, text: '마지막 안내')],
                  onDone: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectCardBy(WidgetTester tester) {
    final target = tester.getRect(find.byKey(last));
    expect(target.top, 400);
    // Less room below than above: the card sits just above where the target ended up.
    final card = tester.getRect(find.text('마지막 안내'));
    expect(card.bottom, lessThan(target.top));
    expect(card.top, greaterThan(target.top - 150));
  }

  testWidgets('the guide waits for a target that is still moving', (
    tester,
  ) async {
    // Like the choices panel at the end of a lazily built list: it lands a few frames late.
    await pumpOne(tester, _Moving(child: SizedBox(key: last, height: 40)));
    expectCardBy(tester);
  });

  testWidgets('the guide follows a target that moves after it is shown', (
    tester,
  ) async {
    await pumpOne(
      tester,
      _Moving(
        after: const Duration(seconds: 1),
        child: SizedBox(key: last, height: 40),
      ),
    );
    expectCardBy(tester);
  });

  testWidgets('a target off screen still leaves the card on screen', (
    tester,
  ) async {
    await pumpOne(
      tester,
      Stack(
        children: [
          Positioned(
            top: -300,
            child: SizedBox(key: last, width: 100, height: 40),
          ),
        ],
      ),
    );
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(tester.getCenter(find.text('시작하기'))), isTrue);
  });
}

/// Moves its child down over the first frames after it is built.
class _Moving extends StatefulWidget {
  final Widget child;

  /// When set, the child jumps down once after this long instead of over the first frames.
  final Duration? after;

  const _Moving({required this.child, this.after});

  @override
  State<_Moving> createState() => _MovingState();
}

class _MovingState extends State<_Moving> {
  double top = 0;

  @override
  void initState() {
    super.initState();
    if (widget.after != null) {
      Future.delayed(widget.after!, () {
        if (mounted) setState(() => top = 400);
      });
      return;
    }
    void step() => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || top >= 400) return;
      setState(() => top += 100);
      step();
    });
    step();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Align(alignment: Alignment.topLeft, child: widget.child),
  );
}
