import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/vault/vault_screen.dart';
import '../profile/profile_screen.dart';

import '../screens/creation/mode_selection_screen.dart' as creation_screen;

class SideMenu extends StatelessWidget {
  final int currentIndex;

  const SideMenu({super.key, required this.currentIndex});

  void _navigateTo(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const ExploreScreen();
        break;
      case 2:
        screen = const creation_screen.CreationModeSelectionScreen();
        break;
      case 3:
        screen = const CharacterVaultScreen();
        break;
      case 4:
        screen = const ProfileScreen();
        break;
      default:
        screen = const HomeScreen();
    }

    // Replace to keep history flat when navigating from side menu
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 250,
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: palette.text, size: 28),
                const SizedBox(width: 12),
                Text(
                  "NovelAIne",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _SideMenuItem(
            icon: Icons.menu_book,
            title: "내 서재",
            isSelected: currentIndex == 0,
            onTap: () => _navigateTo(context, 0),
          ),
          _SideMenuItem(
            icon: Icons.explore_outlined,
            title: "탐색",
            isSelected: currentIndex == 1,
            onTap: () => _navigateTo(context, 1),
          ),
          _SideMenuItem(
            icon: Icons.edit,
            title: "창작하기",
            isSelected: currentIndex == 2,
            onTap: () => _navigateTo(context, 2),
          ),
          _SideMenuItem(
            icon: Icons.archive_outlined,
            title: "캐릭터 보관함",
            isSelected: currentIndex == 3,
            onTap: () => _navigateTo(context, 3),
          ),
          const Spacer(),
          Divider(color: palette.line, height: 1),
          _SideMenuItem(
            icon: Icons.person_outline,
            title: "내 프로필",
            isSelected: currentIndex == 4,
            onTap: () => _navigateTo(context, 4),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primaryColor = palette.accent.withValues(alpha: 0.18);
    final textColor = palette.text;
    final textSecondary = palette.muted;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? textColor : textSecondary,
              size: 17.6, // 80% of 22
            ),
            const SizedBox(width: 12.8), // 80% of 16
            Text(
              title,
              style: TextStyle(
                color: isSelected ? textColor : textSecondary,
                fontSize: 12.8, // 80% of 16
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
