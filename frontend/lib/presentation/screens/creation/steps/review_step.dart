import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_style.dart';
import '../../../../data/models/creation_config.dart';
import '../../../../data/constants/creation_prompts.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ReviewStep extends StatelessWidget {
  final CreationConfig config;
  final VoidCallback onSubmit;
  final VoidCallback onPrev;

  const ReviewStep({
    super.key,
    required this.config,
    required this.onSubmit,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.reviewSettings,
            style: style.title(
              TextStyle(
                color: palette.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            "선택하신 설정을 마지막으로 확인해 주세요.\n곧 당신의 이야기가 시작됩니다.",
            style: TextStyle(color: palette.muted, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 40),

          _StoryPreviewCard(config: config)
              .animate()
              .fadeIn(delay: 200.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: onPrev,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.muted,
                    side: BorderSide(
                      color: style.edge(palette),
                      width: style.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(style.radiusSmall),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                  ),
                  child: const Text("이전"),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.startNewAdventure,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

class _StoryPreviewCard extends StatelessWidget {
  final CreationConfig config;

  const _StoryPreviewCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return Container(
      width: double.infinity,
      decoration: style.card(palette),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(style.radius),
        child: Stack(
          children: [
            // Decorative background element
            if (style.isNight)
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent.withValues(alpha: 0.1),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            style.radiusSmall,
                          ),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: palette.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "스토리 요약",
                        style: style.title(
                          TextStyle(
                            color: palette.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _InfoRow(
                    label: "세계관",
                    value:
                        "${CreationPrompts.displayName(config.genreLabel ?? '')} · ${CreationPrompts.displayName(config.toneLabel ?? '')}",
                    icon: Icons.public_rounded,
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    label: "주인공",
                    value: config.userName ?? "미정",
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    label: "특징",
                    value: config.personalityTraits.isEmpty
                        ? "설정된 특징 없음"
                        : config.personalityTraits.join(", "),
                    icon: Icons.style_rounded,
                  ),
                  const SizedBox(height: 24),
                  Divider(color: palette.line, height: 1),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: palette.accent.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "작성하신 설정을 바탕으로 AI가 첫 장면을 집필합니다.",
                          style: TextStyle(
                            color: palette.faint,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.faint),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: palette.faint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
