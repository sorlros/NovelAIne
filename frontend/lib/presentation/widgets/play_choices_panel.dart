import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_palette.dart';
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
    required this.onChoose,
    required this.onWrite,
    required this.onUndo,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _body(palette),
          if (remainingTurns != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '오늘 남은 장면 $remainingTurns',
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
                style: TextButton.styleFrom(foregroundColor: palette.muted),
              ),
            ),
        ],
      ),
    );
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
        for (final choice in current.choices)
          _ChoiceButton(choice: choice, onTap: () => onChoose(choice)),
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

class _ChoiceButton extends StatelessWidget {
  final PlayChoice choice;
  final VoidCallback onTap;
  const _ChoiceButton({required this.choice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    choice.label,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (choice.lasting) ...[
                  const SizedBox(width: 10),
                  const _RememberedMark(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('직접 입력'),
          style: TextButton.styleFrom(foregroundColor: palette.muted),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
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
              style: TextButton.styleFrom(foregroundColor: palette.muted),
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
    return Tooltip(
      message: '이 선택은 이야기에 남습니다',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_rounded, color: palette.accent, size: 14),
          const SizedBox(width: 3),
          Text('기억됩니다', style: TextStyle(color: palette.accent, fontSize: 11)),
        ],
      ),
    );
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
