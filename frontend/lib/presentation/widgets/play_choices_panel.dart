import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../../data/models/play_models.dart';

/// What a skeleton story offers under the latest scene: the scene's question,
/// its choices, the reader's own action, and undo. Replaces the free-text
/// input of legacy stories.
class PlayChoicesPanel extends StatelessWidget {
  final PlayStatus? status;

  /// A scene is being written; choices are disabled.
  final bool busy;

  /// The last status request failed.
  final bool loadFailed;

  /// Scenes a free user may still play today; null hides the counter.
  final int? remainingTurns;

  /// Scenes a free user may play in a day, shown beside [remainingTurns].
  final int turnLimit;
  final ValueChanged<PlayChoice> onChoose;

  /// The reader wrote their own action instead of picking a choice.
  final ValueChanged<String> onWrite;
  final VoidCallback onUndo;
  final VoidCallback onReload;

  const PlayChoicesPanel({
    super.key,
    required this.status,
    required this.busy,
    required this.loadFailed,
    this.remainingTurns,
    this.turnLimit = 10,
    required this.onChoose,
    required this.onWrite,
    required this.onUndo,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _body(palette),
        if (remainingTurns != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '오늘 남은 장면 $remainingTurns / $turnLimit',
              style: TextStyle(color: palette.faint, fontSize: 12),
            ),
          ),
        if (status != null && status!.canUndo && !busy)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text('직전 선택 되돌리기'),
              style: _quietButton(palette, style),
            ),
          ),
      ],
    );
    // The frame: a rounded card at night, a single ink rule on paper, no box on the route.
    switch (style.kind) {
      case StyleKind.night:
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(style.radiusLarge),
            border: Border.all(color: palette.line),
          ),
          child: child,
        );
      case StyleKind.paper:
        return Container(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.text, width: 2)),
          ),
          child: child,
        );
      case StyleKind.route:
        return Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 4, 10),
          child: child,
        );
    }
  }

  Widget _body(AppPalette palette) {
    final current = status;
    if (loadFailed) {
      return _Notice(
        text: '선택지를 불러오지 못했습니다.',
        action: TextButton(onPressed: onReload, child: const Text('다시 불러오기')),
      );
    }
    if (current == null || busy) {
      return const _Notice(text: '이야기를 이어 쓰고 있습니다...', loading: true);
    }
    if (current.finished) {
      return const _Notice(text: '이야기가 끝났습니다.');
    }
    if (current.preparing || current.choices.isEmpty) {
      return const _Notice(text: '다음 이야기를 준비하고 있습니다...', loading: true);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current.callbacks.isNotEmpty) _Callbacks(names: current.callbacks),
        if (current.question != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              current.question!,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        for (var i = 0; i < current.choices.length; i++)
          _ChoiceButton(
            choice: current.choices[i],
            index: i,
            last: i == current.choices.length - 1,
            onTap: () => onChoose(current.choices[i]),
          ),
        _OwnAction(onWrite: onWrite),
      ],
    );
  }
}

class _Callbacks extends StatelessWidget {
  final List<String> names;
  const _Callbacks({required this.names});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '당신의 선택: ${names.join(' · ')}',
        style: TextStyle(
          color: context.palette.accent,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Quiet text button, shaped by the style (the route style outlines it in ink).
ButtonStyle _quietButton(AppPalette palette, AppStyle style) =>
    TextButton.styleFrom(
      foregroundColor: palette.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.radiusSmall),
        side: style.isRoute
            ? BorderSide(color: palette.text, width: 2)
            : BorderSide.none,
      ),
    );

class _ChoiceButton extends StatelessWidget {
  final PlayChoice choice;
  final int index;
  final bool last;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.choice,
    required this.index,
    required this.last,
    required this.onTap,
  });

  static const _syllables = ['가', '나', '다', '라', '마', '바'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final label = Expanded(
      child: Text(
        choice.label,
        style: TextStyle(
          color: palette.text,
          fontSize: 15,
          height: 1.4,
          fontWeight: style.isRoute ? FontWeight.w700 : null,
        ),
      ),
    );
    final mark = choice.lasting
        ? [const SizedBox(width: 10), const _RememberedMark()]
        : const <Widget>[];

    switch (style.kind) {
      case StyleKind.night:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: palette.raised,
            borderRadius: BorderRadius.circular(style.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(style.radius),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(children: [label, ...mark]),
              ),
            ),
          ),
        );
      case StyleKind.paper:
        return InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
            decoration: BoxDecoration(
              border: last
                  ? null
                  : Border(bottom: BorderSide(color: palette.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    _syllables[index % _syllables.length],
                    style: TextStyle(
                      color: palette.accent,
                      fontFamily: 'Noto Serif KR',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ),
                label,
                ...mark,
              ],
            ),
          ),
        );
      case StyleKind.route:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(style.radius),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: style.card(palette),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.highlight,
                        borderRadius: BorderRadius.circular(style.radiusSmall),
                        border: Border.all(color: palette.text, width: 2),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: palette.onHighlight,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    label,
                    ...mark,
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// "직접 입력": collapsed to a button until the reader opens it.
class _OwnAction extends StatefulWidget {
  final ValueChanged<String> onWrite;
  const _OwnAction({required this.onWrite});

  @override
  State<_OwnAction> createState() => _OwnActionState();
}

class _OwnActionState extends State<_OwnAction> {
  /// The server accepts up to this many characters.
  static const _maxLength = 300;

  final TextEditingController _controller = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onWrite(text);
    _controller.clear();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('직접 입력'),
          style: _quietButton(palette, style),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxLength,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            style: TextStyle(color: palette.text, fontSize: 15),
            decoration: InputDecoration(
              hintText: '어떻게 행동할까요?',
              hintStyle: TextStyle(color: palette.faint),
              helperText: '이루어질 수 없는 행동은 이야기 속에서 실패로 그려집니다.',
              helperStyle: TextStyle(color: palette.faint),
              helperMaxLines: 2,
              counterStyle: TextStyle(color: palette.faint),
              filled: true,
              fillColor: palette.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(style.radius),
                borderSide: style.isNight
                    ? BorderSide.none
                    : BorderSide(
                        color: style.edge(palette),
                        width: style.borderWidth,
                      ),
              ),
              suffixIcon: IconButton(
                tooltip: '보내기',
                onPressed: _submit,
                icon: Icon(Icons.send_rounded, color: palette.accent),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _open = false),
              style: _quietButton(palette, style),
              child: const Text('선택지로 돌아가기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RememberedMark extends StatelessWidget {
  const _RememberedMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final Widget mark;
    switch (style.kind) {
      case StyleKind.night:
        mark = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_rounded, color: palette.accent, size: 14),
            const SizedBox(width: 3),
            Text(
              '이야기에 남음',
              style: TextStyle(color: palette.accent, fontSize: 11),
            ),
          ],
        );
      case StyleKind.paper:
        mark = Transform.rotate(
          angle: -0.2,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent, width: 1.5),
            ),
            child: Text(
              '기억',
              style: TextStyle(
                color: palette.accent,
                fontFamily: 'Noto Serif KR',
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        );
      case StyleKind.route:
        mark = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: palette.text,
            borderRadius: BorderRadius.circular(style.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: 0.785398,
                child: Container(width: 6, height: 6, color: palette.highlight),
              ),
              const SizedBox(width: 5),
              Text(
                '길에 남음',
                style: TextStyle(
                  color: palette.highlight,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
    }
    return Tooltip(message: '이 선택은 이야기에 남습니다', child: mark);
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final bool loading;
  final Widget? action;
  const _Notice({required this.text, this.loading = false, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (loading) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(text, style: TextStyle(color: palette.muted)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
