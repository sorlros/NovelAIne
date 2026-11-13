import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../providers/theme_provider.dart';

/// Where the reader picks the screen theme. The pick applies at once and is kept on the device.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final choice = ref.watch(themeChoiceProvider);
    final themes = ref.read(themeChoiceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('화면 테마')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                '고르면 바로 바뀝니다. 이 기기에 저장됩니다.',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              for (final theme in AppThemeId.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ThemeOption(
                    theme: theme,
                    selected: choice == theme.name,
                    onTap: () => themes.choose(theme.name),
                  ),
                ),
              const SizedBox(height: 6),
              _FollowDevice(
                on: choice == followDevice,
                onChanged: (on) => themes.choose(
                  on
                      ? followDevice
                      // Turned off: keep the theme the device setting was showing.
                      : (palette.brightness == Brightness.light
                                ? AppThemeId.wongoji
                                : AppThemeId.simya)
                            .name,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final AppThemeId theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? palette.accent : palette.line,
        width: 1.5,
      ),
    );
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? palette.surface : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Preview(palette: theme.palette),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.label,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        theme.description,
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? palette.accent : palette.faint,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accent,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small picture of a theme: its page, two lines of text and its accent.
class _Preview extends StatelessWidget {
  final AppPalette palette;
  const _Preview({required this.palette});

  @override
  Widget build(BuildContext context) {
    Widget bar(Color color, double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: 76,
        height: 58,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.ground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(palette.text, 1),
            const SizedBox(height: 5),
            bar(palette.muted, 0.7),
            const Spacer(),
            Container(
              width: 34,
              height: 12,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowDevice extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;

  const _FollowDevice({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기기 설정 따르기',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '낮에는 ${AppThemeId.wongoji.label}, 밤에는 ${AppThemeId.simya.label}',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Switch(value: on, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
