import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_palette.dart';

class CharacterCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isProtagonist;
  final bool isImportant;
  final VoidCallback onTap;

  const CharacterCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.isProtagonist = false,
    this.isImportant = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect for important characters
                if (isImportant || isProtagonist)
                  Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: palette.accent.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 2.seconds,
                      ),

                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isProtagonist
                          ? palette.accent.withValues(alpha: 0.8)
                          : (isImportant ? palette.accent : palette.line),
                      width: 2,
                    ),
                    color: palette.surface,
                  ),
                  child: ClipOval(
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: palette.raised,
                              highlightColor: palette.line,
                              child: Container(color: Colors.black),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.person, color: palette.faint),
                          )
                        : Icon(Icons.person, color: palette.faint, size: 30),
                  ),
                ),

                // Protagonist Badge
                if (isProtagonist)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: palette.onAccent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: palette.text,
                fontSize: 11,
                fontWeight: isImportant || isProtagonist
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }
}
