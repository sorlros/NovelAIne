import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';

/// How far the reader is in a story, drawn the theme's way: a strip of frames at night (scenes with a
/// picture lit), a line of stops on the route, the scene number on paper.
class SceneProgress extends StatelessWidget {
  /// The scene the reader is on, from 1.
  final int current;

  /// Scenes (from 1) that have a picture; the night strip lights them.
  final Set<int> pictured;

  /// Frames or stops shown, ending a little after [current].
  final int span;

  /// Draw on the accent band (white stops), as the route style's headers do.
  final bool onBand;

  const SceneProgress({
    super.key,
    required this.current,
    this.pictured = const {},
    this.span = 10,
    this.onBand = false,
  });

  /// The scenes shown: the last ones read, the current one, and a few still to come.
  List<int> get _shown {
    final last = current < span ? span : current + 2;
    final first = (last - span + 1).clamp(1, last);
    return [for (var i = first; i <= last; i++) i];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return Semantics(
      label: '장면 $current',
      child: ExcludeSemantics(
        child: switch (style.kind) {
          StyleKind.night => _strip(palette),
          StyleKind.route => _route(palette),
          StyleKind.paper => _number(palette, style),
        },
      ),
    );
  }

  Widget _strip(AppPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final scene in _shown)
          Container(
            width: 22,
            height: 12,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: scene > current
                  ? null
                  : pictured.contains(scene)
                  ? palette.accent
                  : palette.line,
              borderRadius: BorderRadius.circular(2),
              border: scene == current
                  ? Border.all(color: palette.text, width: 2)
                  : scene > current
                  ? Border.all(color: palette.line)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _route(AppPalette palette) {
    final ink = onBand ? palette.onAccent : palette.text;
    final hollow = onBand ? palette.accent : palette.surface;
    final stops = _shown.where((scene) => scene <= current).toList();
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final scene in stops) ...[
            if (scene != stops.first)
              Container(width: 18, height: 2.5, color: ink),
            if (scene == current)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.highlight,
                  border: Border.all(color: palette.text, width: 2.5),
                ),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.text,
                  ),
                ),
              )
            else
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hollow,
                  border: Border.all(color: ink, width: 2.5),
                ),
              ),
          ],
          const SizedBox(width: 4),
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 2.5,
              margin: const EdgeInsets.only(left: 3),
              color: ink,
            ),
        ],
      ),
    );
  }

  Widget _number(AppPalette palette, AppStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('장면', style: TextStyle(color: palette.muted, fontSize: 12)),
        const SizedBox(width: 6),
        Text(
          '$current',
          style: TextStyle(
            color: palette.text,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontFamily: 'Noto Serif KR',
            height: 1,
          ),
        ),
      ],
    );
  }
}
