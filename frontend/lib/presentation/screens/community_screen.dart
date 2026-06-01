import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/community_models.dart';
import '../../data/models/story_model.dart';
import '../../data/services/api_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/responsive_layout.dart';
import 'story_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<CommunityStoryModel>> _feedFuture;
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
    _feedFuture = _loadFeed();
  }

  Future<List<CommunityStoryModel>> _loadFeed() {
    return _apiService.fetchCommunityFeed(genre: _selectedGenre);
  }

  void _selectGenre(String? genre) {
    setState(() {
      _selectedGenre = genre;
      _feedFuture = _loadFeed();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _feedFuture = _loadFeed();
    });
    await _feedFuture;
  }

  Future<void> _toggleLike(CommunityStoryModel item) async {
    try {
      await _apiService.setStoryLike(item.story.id, isLiked: !item.isLiked);
      if (!mounted) return;
      setState(() {
        _feedFuture = _loadFeed();
      });
    } catch (error) {
      _showError('좋아요를 반영하지 못했습니다. 로그인 상태를 확인해주세요.');
    }
  }

  Future<void> _openComments(CommunityStoryModel item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(story: item.story),
    );
    if (!mounted) return;
    setState(() {
      _feedFuture = _loadFeed();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7F1D1D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return ResponsiveLayout(
      currentIndex: 1,
      appBar: AppBar(
        title: const Text('커뮤니티'),
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
            FutureBuilder<List<CommunityStoryModel>>(
              future: _feedFuture,
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
                    child: _CommunityMessage(
                      icon: Icons.cloud_off_rounded,
                      title: '커뮤니티 피드를 불러오지 못했습니다.',
                      description: '${snapshot.error}',
                    ),
                  );
                }

                final feed = snapshot.data ?? [];
                if (feed.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _CommunityMessage(
                      icon: Icons.forum_outlined,
                      title: '아직 공유된 이야기가 없습니다.',
                      description: '공개 스토리가 생기면 댓글과 좋아요로 의견을 나눌 수 있습니다.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 32,
                    12,
                    isMobile ? 16 : 32,
                    120,
                  ),
                  sliver: SliverList.builder(
                    itemCount: feed.length,
                    itemBuilder: (context, index) {
                      final item = feed[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CommunityStoryCard(
                          item: item,
                          onRead: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoryScreen(
                                  initialStory: item.story,
                                  readOnly: true,
                                ),
                              ),
                            );
                          },
                          onLike: () => _toggleLike(item),
                          onComments: () => _openComments(item),
                        ),
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
          Text(
            '커뮤니티',
            style: GoogleFonts.notoSerif(
              color: Colors.white,
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '공개된 인터랙티브 스토리에 반응을 남기고 창작자와 독자가 함께 이야기를 확장합니다.',
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

class _CommunityStoryCard extends StatelessWidget {
  final CommunityStoryModel item;
  final VoidCallback onRead;
  final VoidCallback onLike;
  final VoidCallback onComments;

  const _CommunityStoryCard({
    required this.item,
    required this.onRead,
    required this.onLike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    final story = item.story;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: story.genre.toUpperCase()),
              _Tag(label: story.narrativeType == 'ensemble' ? '군상극' : '주인공'),
              _Tag(label: story.status == 'completed' ? '완결' : '연재중'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            story.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerif(
              color: Colors.white,
              fontSize: 22,
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
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  story.authorUsername ?? 'Traveler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              _Metric(
                icon: Icons.menu_book_outlined,
                label: '${story.totalScenes}',
              ),
              const SizedBox(width: 12),
              _Metric(
                icon: Icons.favorite_border_rounded,
                label: '${item.likeCount}',
              ),
              const SizedBox(width: 12),
              _Metric(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${item.commentCount}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onRead,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                label: const Text('읽기'),
              ),
              OutlinedButton.icon(
                onPressed: onLike,
                style: OutlinedButton.styleFrom(
                  foregroundColor: item.isLiked
                      ? const Color(0xFFFF8AAE)
                      : Colors.white70,
                  side: BorderSide(
                    color: item.isLiked
                        ? const Color(0xFFFF8AAE)
                        : Colors.white24,
                  ),
                ),
                icon: Icon(
                  item.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(item.isLiked ? '좋아요 취소' : '좋아요'),
              ),
              OutlinedButton.icon(
                onPressed: onComments,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.mode_comment_outlined, size: 18),
                label: const Text('댓글'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final StoryModel story;

  const _CommentsSheet({required this.story});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  late Future<List<StoryCommentModel>> _commentsFuture;
  bool _isSubmitting = false;
  final Set<String> _pendingCommentActions = {};

  @override
  void initState() {
    super.initState();
    _commentsFuture = _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<List<StoryCommentModel>> _loadComments() {
    return _apiService.fetchStoryComments(widget.story.id);
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await _apiService.addStoryComment(widget.story.id, content);
      _commentController.clear();
      setState(() {
        _commentsFuture = _loadComments();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 등록하지 못했습니다. 로그인 상태를 확인해주세요.'),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(StoryCommentModel comment) async {
    if (_pendingCommentActions.contains(comment.id)) return;
    setState(() => _pendingCommentActions.add(comment.id));
    try {
      await _apiService.deleteStoryComment(comment.id);
      setState(() {
        _commentsFuture = _loadComments();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글을 삭제했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글을 삭제하지 못했습니다. 권한 또는 네트워크 상태를 확인해주세요.'),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingCommentActions.remove(comment.id));
    }
  }

  Future<void> _reportComment(StoryCommentModel comment) async {
    if (_pendingCommentActions.contains(comment.id)) return;
    setState(() => _pendingCommentActions.add(comment.id));
    try {
      await _apiService.reportStoryComment(comment.id);
      setState(() {
        _commentsFuture = _loadComments();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('신고를 접수하지 못했습니다. 로그인 상태를 확인해주세요.'),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingCommentActions.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentUser = ref.watch(authProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF120F1D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.story.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white60,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<StoryCommentModel>>(
                    future: _commentsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C3AED),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _CommunityMessage(
                          icon: Icons.cloud_off_rounded,
                          title: '댓글을 불러오지 못했습니다.',
                          description: '${snapshot.error}',
                        );
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const _CommunityMessage(
                          icon: Icons.mode_comment_outlined,
                          title: '첫 댓글을 남겨보세요.',
                          description: '작품의 감상과 응원을 창작자에게 전달할 수 있습니다.',
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return _CommentTile(
                            comment: comment,
                            currentUserId: currentUser?.id,
                            isPending: _pendingCommentActions.contains(
                              comment.id,
                            ),
                            onDelete: () => _deleteComment(comment),
                            onReport: () => _reportComment(comment),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const Divider(color: Colors.white10, height: 24),
                        itemCount: comments.length,
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 3,
                            maxLength: 1000,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '댓글을 입력하세요',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _isSubmitting ? null : _submitComment,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final StoryCommentModel comment;
  final String? currentUserId;
  final bool isPending;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.isPending,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final canDelete = currentUserId != null && currentUserId == comment.userId;
    final canReport = currentUserId != null && currentUserId != comment.userId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
          backgroundImage: comment.authorAvatarUrl == null
              ? null
              : NetworkImage(comment.authorAvatarUrl!),
          child: comment.authorAvatarUrl == null
              ? const Icon(
                  Icons.person_outline,
                  color: Colors.white70,
                  size: 18,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.authorUsername,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(comment.createdAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  if (isPending)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (canDelete || canReport)
                    PopupMenuButton<String>(
                      tooltip: '댓글 관리',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                      color: const Color(0xFF1D1930),
                      onSelected: (value) {
                        if (value == 'delete') onDelete();
                        if (value == 'report') onReport();
                      },
                      itemBuilder: (context) => [
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              '삭제',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if (canReport)
                          const PopupMenuItem(
                            value: 'report',
                            child: Text(
                              '신고',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.content,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
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

class _CommunityMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _CommunityMessage({
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${local.month}/${local.day}';
}
