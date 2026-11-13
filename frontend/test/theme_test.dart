import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/presentation/providers/theme_provider.dart';
import 'package:frontend/presentation/screens/profile/theme_screen.dart';

/// WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

/// The app as `main` builds it, opened on the theme screen.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    final picked = choice == followDevice
        ? null
        : AppThemeId.values.byName(choice).palette;
    return MaterialApp(
      theme: AppTheme.of(picked ?? AppThemeId.wongoji.palette),
      darkTheme: AppTheme.of(picked ?? AppThemeId.simya.palette),
      home: const ThemeScreen(),
    );
  }
}

void main() {
  group('palettes', () {
    for (final theme in AppThemeId.values) {
      final p = theme.palette;

      test('${theme.name}: text can be read on every background', () {
        for (final background in [p.ground, p.surface, p.raised]) {
          expect(contrast(p.text, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.muted, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.accent, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.danger, background), greaterThanOrEqualTo(4.5));
          expect(contrast(p.faint, background), greaterThanOrEqualTo(3));
        }
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
      });

      testWidgets('${theme.name}: the Material theme carries the palette', (
        tester,
      ) async {
        final data = AppTheme.of(p);
        expect(data.extension<AppPalette>(), p);
        expect(data.brightness, p.brightness);
        expect(data.scaffoldBackgroundColor, p.ground);
        expect(data.colorScheme.primary, p.accent);
      });
    }
  });

  group('ThemeChoice', () {
    test('an unknown or missing saved choice gives the default theme', () {
      expect(ThemeChoice(null).state, AppThemeId.simya.name);
      expect(ThemeChoice('purple').state, AppThemeId.simya.name);
      expect(ThemeChoice('wongoji').state, 'wongoji');
      expect(ThemeChoice(followDevice).state, followDevice);
    });

    test('only a known choice is taken', () {
      final choice = ThemeChoice(null);
      choice.choose('meok');
      expect(choice.state, 'meok');
      choice.choose('purple');
      expect(choice.state, 'meok');
    });
  });

  testWidgets('picking a theme changes the app at once', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _App()));
    BuildContext context() => tester.element(find.byType(ThemeScreen));
    expect(context().palette, AppThemeId.simya.palette);

    for (final theme in AppThemeId.values) {
      expect(find.text(theme.label), findsOneWidget);
    }

    await tester.tap(find.text(AppThemeId.wongoji.label));
    await tester.pumpAndSettle();
    expect(context().palette, AppThemeId.wongoji.palette);
    expect(Theme.of(context()).brightness, Brightness.light);
  });

  testWidgets('following the device uses the paper theme by day', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const ProviderScope(child: _App()));

    // The switch sits under the five themes, below the test screen's fold.
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ThemeScreen));
    expect(context.palette, AppThemeId.wongoji.palette);

    // Turned off again, the theme on screen stays as the picked one.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(context);
    expect(container.read(themeChoiceProvider), AppThemeId.wongoji.name);
  });

  test('screens name no colour of their own', () {
    final literal = RegExp(r'Color\(0x');
    final offenders = Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => literal.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty, reason: 'use context.palette instead');
  });
}
