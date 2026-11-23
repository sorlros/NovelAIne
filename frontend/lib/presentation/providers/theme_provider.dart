import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../data/services/theme_store.dart';

/// The choice that follows the device: the paper theme by day, the night theme in dark mode.
const String followDevice = 'system';

/// What the reader picked on the theme screen: an [AppThemeId] name or [followDevice].
class ThemeChoice extends StateNotifier<String> {
  /// [saved] is what the device kept; anything it does not know gives the default theme.
  ThemeChoice(String? saved)
    : super(_known(saved) ? saved! : AppThemeId.simya.name);

  static bool _known(String? choice) =>
      choice == followDevice ||
      AppThemeId.values.any((theme) => theme.name == choice);

  void choose(String choice) {
    if (!_known(choice) || choice == state) return;
    state = choice;
    ThemeStore().write(choice);
  }
}

/// Overridden in `main` with the choice read from the device, so the first frame has the right theme.
final themeChoiceProvider = StateNotifierProvider<ThemeChoice, String>(
  (ref) => ThemeChoice(null),
);
