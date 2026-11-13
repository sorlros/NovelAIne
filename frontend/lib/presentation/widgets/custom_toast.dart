import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';

enum ToastType { success, error, info }

class CustomToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            message: message,
            type: type,
            onDismiss: () => overlayEntry.remove(),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    IconData icon;
    Color accentColor;

    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_rounded;
        accentColor = palette.success;
        break;
      case ToastType.error:
        icon = Icons.error_rounded;
        accentColor = palette.danger;
        break;
      case ToastType.info:
        icon = Icons.info_rounded;
        accentColor = palette.accent;
        break;
    }

    return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(style.radiusLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: style.isNight ? 10 : 0,
                  sigmaY: style.isNight ? 10 : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: style.isNight
                      ? BoxDecoration(
                          color: palette.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            style.radiusLarge,
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        )
                      : style
                            .card(palette)
                            .copyWith(
                              borderRadius: BorderRadius.circular(
                                style.radiusLarge,
                              ),
                            ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accentColor, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          message,
                          style: style.title(
                            GoogleFonts.notoSerif(
                              color: palette.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack);
  }
}
