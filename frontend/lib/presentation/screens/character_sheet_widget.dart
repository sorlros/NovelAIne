import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CharacterSheetWidget extends StatelessWidget {
  final Map<String, dynamic> character;
  final bool isProtagonist;

  const CharacterSheetWidget({
    super.key, 
    required this.character,
    this.isProtagonist = false,
  });

  @override
  Widget build(BuildContext context) {
    final String name = character['name'] ?? 'Unknown Character';
    final String? imageUrl = character['image_url'];
    final String description = character['description'] ?? 'No description available.';
    final String? appearance = character['appearance_description'];
    final List<dynamic> traits = character['personality_traits'] ?? [];
    final String? background = character['background_story'];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D12).withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Profile
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isProtagonist ? Colors.amber : const Color(0xFF7C3AED),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isProtagonist ? Colors.amber : const Color(0xFF7C3AED))
                                      .withValues(alpha: 0.3),
                                  blurRadius: 25,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.05)),
                                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 60, color: Colors.white24),
                                    )
                                  : const Icon(Icons.person, size: 60, color: Colors.white24),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            name,
                            style: GoogleFonts.notoSerif(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (isProtagonist)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                "PROTAGONIST",
                                style: GoogleFonts.lato(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fadeIn().moveY(begin: 30, end: 0),

                    const SizedBox(height: 48),

                    // Bio Section
                    _buildSectionHeader(context, "개요"),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: GoogleFonts.notoSerif(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        height: 1.7,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    if (traits.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _buildSectionHeader(context, "성격 특징"),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: traits.map((trait) => _buildTraitChip(trait.toString())).toList(),
                      ).animate().fadeIn(delay: 300.ms),
                    ],

                    if (appearance != null && appearance.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _buildSectionHeader(context, "외모"),
                      const SizedBox(height: 16),
                      Text(
                        appearance,
                        style: GoogleFonts.notoSerif(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],

                    if (background != null && background.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _buildSectionHeader(context, "배경 이야기"),
                      const SizedBox(height: 16),
                      Text(
                        background,
                        style: GoogleFonts.notoSerif(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ).animate().fadeIn(delay: 500.ms),
                    ],
                    
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.notoSerif(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTraitChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
    );
  }
}
