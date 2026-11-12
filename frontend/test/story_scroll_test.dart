import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/screens/story_screen.dart';

Map<String, dynamic> scene(String id) => {'id': id, 'role': 'ai'};
Map<String, dynamic> move(String id) => {'id': id, 'role': 'user'};

void main() {
  group('latestSceneIndex', () {
    test('is the last scene, skipping the reader\'s moves after it', () {
      expect(latestSceneIndex([scene('a'), move('b'), scene('c')]), 2);
      expect(latestSceneIndex([scene('a'), move('b')]), 0);
    });

    test('is null without a scene', () {
      expect(latestSceneIndex([]), isNull);
      expect(latestSceneIndex([move('a')]), isNull);
    });
  });

  group('itemTopOffset', () {
    const itemHeight = 200.0;
    const topPadding = 20.0;
    late ScrollController controller;

    Future<void> pumpList(WidgetTester tester) async {
      controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                const SliverAppBar(title: Text('story'), floating: true),
              ],
              body: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(top: topPadding, bottom: 440),
                itemCount: 30,
                itemBuilder: (context, index) => SizedBox(
                  key: ValueKey('s$index'),
                  height: itemHeight,
                  child: Text('scene $index'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is null until the lazy list builds the item', (tester) async {
      await pumpList(tester);
      expect(itemTopOffset(controller.position, 's28'), isNull);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(
        itemTopOffset(controller.position, 's28'),
        topPadding + 28 * itemHeight,
      );
    });

    testWidgets('puts the item right under the app bar', (tester) async {
      await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      controller.jumpTo(itemTopOffset(controller.position, 's28')!);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('s28'))).dy,
        tester.getTopLeft(find.byType(ListView)).dy,
      );
    });
  });
}
