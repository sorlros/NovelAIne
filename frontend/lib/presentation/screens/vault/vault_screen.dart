import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_style.dart';
import '../../providers/content_provider.dart';
import '../character_sheet_widget.dart';
import '../../widgets/responsive_layout.dart';

class CharacterVaultScreen extends ConsumerStatefulWidget {
  const CharacterVaultScreen({super.key});

  @override
  ConsumerState<CharacterVaultScreen> createState() =>
      _CharacterVaultScreenState();
}

class _CharacterVaultScreenState extends ConsumerState<CharacterVaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final charactersAsync = ref.watch(charactersProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return ResponsiveLayout(
      currentIndex: 3,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "캐릭터 보관함",
          style: style.title(
            GoogleFonts.notoSerif(
              color: palette.text,
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.muted,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  8,
                  isMobile ? 16 : 24,
                  isMobile ? 16 : 24,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: style.card(palette),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: palette.text, fontSize: 15),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      icon: Icon(
                        Icons.search_rounded,
                        color: palette.faint,
                        size: 20,
                      ),
                      hintText: "이름으로 캐릭터 검색...",
                      hintStyle: TextStyle(color: palette.faint, fontSize: 14),
                      // The box around the field is its fill and outline: none of the theme's.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: charactersAsync.when(
                  data: (characters) {
                    final vaultedOnes = characters.where((c) {
                      final matchesVault = c.isInVault;
                      final matchesSearch = c.name.toLowerCase().contains(
                        _searchQuery,
                      );
                      return matchesVault && matchesSearch;
                    }).toList();

                    if (vaultedOnes.isEmpty) {
                      return _buildEmptyState(palette);
                    }

                    // Dynamic column count
                    int crossAxisCount = 2;
                    if (screenWidth >= 1400) {
                      crossAxisCount = 5;
                    } else if (screenWidth >= 1100) {
                      crossAxisCount = 4;
                    } else if (screenWidth >= 800) {
                      crossAxisCount = 3;
                    }

                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24,
                        0,
                        isMobile ? 16 : 24,
                        100, // Extra bottom padding
                      ),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: isMobile ? 0.8 : 0.85,
                        crossAxisSpacing: isMobile ? 12 : 16,
                        mainAxisSpacing: isMobile ? 12 : 16,
                      ),
                      itemCount: vaultedOnes.length,
                      itemBuilder: (context, index) {
                        final char = vaultedOnes[index];
                        return _VaultCharacterCard(
                              char: char,
                              onTap: () => showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => CharacterSheetWidget(
                                  character: {
                                    'id': char.id,
                                    'name': char.name,
                                    'description': char.description,
                                    'personality_traits':
                                        char.personalityTraits,
                                    'background_story': char.backgroundStory,
                                    'appearance_description':
                                        char.appearanceDescription,
                                    'image_url': char.imageUrl,
                                    'is_in_vault': char.isInVault,
                                  },
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (index * 50).ms)
                            .scale(begin: const Offset(0.9, 0.9));
                      },
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      "Error: $err",
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 64, color: palette.faint),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? "보관함이 비어 있습니다." : "검색 결과가 없습니다.",
            style: TextStyle(
              color: palette.faint,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                "이야기를 읽는 중에 매력적인 인물을 발견하면\n보관함에 저장해 보세요!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.faint,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _VaultCharacterCard extends StatelessWidget {
  final dynamic char;
  final VoidCallback onTap;

  const _VaultCharacterCard({required this.char, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: style.card(palette),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: char.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: char.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: palette.accent.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: palette.faint,
                          ),
                        ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          char.name,
                          style: style.title(
                            TextStyle(
                              color: palette.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          char.description,
                          style: TextStyle(color: palette.faint, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: palette.accent,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
