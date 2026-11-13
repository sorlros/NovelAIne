import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_palette.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/auth_screen.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'widgets/user_header_widget.dart';
import 'widgets/my_library_tab.dart';
import 'widgets/my_creations_tab.dart';
import '../widgets/responsive_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    // Clears the stored session too; revoking on the server alone left it to be restored.
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;

    // Auth Flow: Navigate back to AuthScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ResponsiveLayout(
      currentIndex: 4,
      appBar: AppBar(
        title: Text(
          "내 프로필",
          style: TextStyle(fontWeight: FontWeight.bold, color: palette.text),
        ),
        backgroundColor: palette.ground,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.text),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: palette.muted),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // 1. User Information Header
                  const UserHeaderWidget(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: palette.onAccent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelColor: palette.muted,
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: [
                    Tab(text: AppLocalizations.of(context)!.myLibrary),
                    Tab(text: AppLocalizations.of(context)!.myCreations),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [MyLibraryTab(), MyCreationsTab()],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 32; // Add padding
  @override
  double get maxExtent => tabBar.preferredSize.height + 32;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final palette = context.palette;
    return Container(
      color: palette
          .ground, // Match background to obscure content scrolling underneath
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true; // colours follow the theme, so the header is rebuilt with it
  }
}
