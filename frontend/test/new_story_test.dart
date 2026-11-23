import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/presentation/screens/creation/mode_selection_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('create button waits for a genre and a tone', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.of(AppThemeId.simya),
          home: const CreationModeSelectionScreen(),
        ),
      ),
    );

    ElevatedButton button() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '이야기 만들기'),
    );

    expect(find.text('어떤 이야기를 읽고 싶나요?'), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.tap(find.text('판타지'));
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.tap(find.text('가볍게'));
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}
