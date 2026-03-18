import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
                          color: (isProtagonist ? Colors.amber : const Color(0xFF7C3AED))
                              .withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isProtagonist 
                          ? Colors.amber.withValues(alpha: 0.8) 
                          : (isImportant ? const Color(0xFF7C3AED) : Colors.white24),
                      width: 2,
                    ),
                    color: const Color(0xFF1A1A24),
                  ),
                  child: ClipOval(
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white24),
                          )
                        : const Icon(Icons.person, color: Colors.white24, size: 30),
                  ),
                ),

                // Protagonist Badge
                if (isProtagonist)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.star, size: 12, color: Colors.black),
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
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: isImportant || isProtagonist ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }
}
