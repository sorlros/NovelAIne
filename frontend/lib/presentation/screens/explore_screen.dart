import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/story_model.dart';
import '../../data/services/api_service.dart';
import '../widgets/responsive_layout.dart';
import 'community_screen.dart';
import 'story_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<StoryModel>> _storiesFuture;
  String? _selectedGenre;

  static const List<Map<String, String?>> _genreFilters = [
    {'label': '전체', 'value': null},
    {'label': '판타지', 'value': 'fantasy'},
    {'label': 'SF', 'value': 'scifi'},
    {'label': '미스터리', 'value': 'mystery'},
    {'label': '로맨스', 'value': 'romance'},
    {'label': '무협', 'value': 'wuxia'},
    {'label': '아포칼립스', 'value': 'apocalypse'},
  ];

  @override
  void initState() {
    super.initState();
    _storiesFuture = _loadStories();
  }

  Future<List<StoryModel>> _loadStories() {
    return _apiService.fetchPublicStories(genre: _selectedGenre);
  }

  void _selectGenre(String? genre) {
    setState(() {
      _selectedGenre = genre;
      _storiesFuture = _loadStories();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _storiesFuture = _loadStories();
    });
    await _storiesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return ResponsiveLayout(
      currentIndex: 1,
      appBar: AppBar(
        title: const Text('탐색'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF7C3AED),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isMobile)),
            SliverToBoxAdapter(child: _buildGenreFilters()),
            FutureBuilder<List<StoryModel>>(
              future: _storiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ExploreMessage(
                      icon: Icons.cloud_off_rounded,
                      title: '공개 서재를 불러오지 못했습니다.',
                      description: '${snapshot.error}',
                    ),
                  );
                }

                final stories = snapshot.data ?? [];
                if (stories.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ExploreMessage(
                      icon: Icons.auto_stories_outlined,
                      title: '아직 공개된 이야기가 없습니다.',
                      description: '프로필에서 내 작품을 공개하면 이곳에 표시됩니다.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 32,
                    8,
                    isMobile ? 16 : 32,
                    120,
                  ),
                  sliver: SliverGrid.builder(
                    itemCount: stories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isMobile ? 1.45 : 0.92,
                    ),
                    itemBuilder: (context, index) {
                      return _PublicStoryCard(
                        story: stories[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryScreen(
                                initialStory: stories[index],
                                readOnly: true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 20 : 36,
        12,
        isMobile ? 20 : 36,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                '공개 서재',
                style: GoogleFonts.notoSerif(
                  color: Colors.white,
                  fontSize: isMobile ? 28 : 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CommunityScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('커뮤니티'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '다른 창작자들이 공개한 인터랙티브 스토리를 읽고 영감을 얻어보세요.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: isMobile ? 14 : 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreFilters() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = _genreFilters[index];
          final value = filter['value'];
          final isSelected = value == _selectedGenre;
          return ChoiceChip(
            label: Text(filter['label']!),
            selected: isSelected,
            onSelected: (_) => _selectGenre(value),
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? const Color(0xFF7C3AED) : Colors.white12,
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _genreFilters.length,
      ),
    );
  }
}

class _PublicStoryCard extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onTap;

  const _PublicStoryCard({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tag(label: story.genre.toUpperCase()),
                const SizedBox(width: 8),
                _Tag(label: story.narrativeType == 'ensemble' ? '군상극' : '주인공'),
              ],
            ),
            const Spacer(),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerif(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              story.description.isEmpty ? '설명이 아직 없습니다.' : story.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                height: 1.45,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    story.authorUsername ?? 'Traveler',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.menu_book_outlined,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${story.totalScenes}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFBCA7FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ExploreMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ExploreMessage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white24),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
