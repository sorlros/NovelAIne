import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    IconData icon;
    Color accentColor;

    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_rounded;
        accentColor = const Color(0xFF9ECE6A);
        break;
      case ToastType.error:
        icon = Icons.error_rounded;
        accentColor = const Color(0xFFF7768E);
        break;
      case ToastType.info:
        icon = Icons.info_rounded;
        accentColor = const Color(0xFF7AA2F7);
        break;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1B26).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: accentColor, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.notoSerif(
                        color: const Color(0xFFC0CAF5),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack);
  }
}
