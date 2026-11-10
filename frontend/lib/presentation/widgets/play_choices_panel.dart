import 'package:flutter/material.dart';

import '../../data/models/play_models.dart';

const _accent = Color(0xFF7C3AED);
const _remembered = Color(0xFFFFD166);

/// What a skeleton story offers under the latest scene: the scene's question,
/// its choices, and undo. Replaces the free-text input of legacy stories.
class PlayChoicesPanel extends StatelessWidget {
  final PlayStatus? status;

  /// A scene is being written; choices are disabled.
  final bool busy;

  /// The last status request failed.
  final bool loadFailed;
  final ValueChanged<PlayChoice> onChoose;
  final VoidCallback onUndo;
  final VoidCallback onReload;

  const PlayChoicesPanel({
    super.key,
    required this.status,
    required this.busy,
    required this.loadFailed,
    required this.onChoose,
    required this.onUndo,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _body(),
          if (status != null && status!.canUndo && !busy)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('직전 선택 되돌리기'),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        for (final choice in current.choices)
          _ChoiceButton(choice: choice, onTap: () => onChoose(choice)),
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
        style: const TextStyle(color: _remembered, fontSize: 12, height: 1.5),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    choice.label,
                    style: const TextStyle(
                      color: Colors.white,
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

class _RememberedMark extends StatelessWidget {
  const _RememberedMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '이 선택은 이야기에 남습니다',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.bookmark_rounded, color: _remembered, size: 14),
          SizedBox(width: 3),
          Text('기억됩니다', style: TextStyle(color: _remembered, fontSize: 11)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (loading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
