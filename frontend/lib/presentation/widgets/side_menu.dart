import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
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
    final style = context.appStyle;
    final route = style.isRoute;
    final onMenu = route ? palette.onAccent : palette.text;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: route ? palette.accent : palette.surface,
        border: Border(
          right: BorderSide(
            color: style.edge(palette),
            width: style.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: onMenu, size: 28),
                const SizedBox(width: 12),
                Text(
                  "NovelAIne",
                  style: style.title(
                    TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: onMenu,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _SideMenuItem(
            icon: Icons.menu_book,
            title: "서재",
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
            title: "만들기",
            isSelected: currentIndex == 2,
            onTap: () => _navigateTo(context, 2),
          ),
          _SideMenuItem(
            icon: Icons.archive_outlined,
            title: "보관함",
            isSelected: currentIndex == 3,
            onTap: () => _navigateTo(context, 3),
          ),
          const Spacer(),
          Divider(color: route ? palette.onAccent : palette.line, height: 1),
          _SideMenuItem(
            icon: Icons.person_outline,
            title: "내 정보",
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
    final style = context.appStyle;
    final route = style.isRoute;
    final Color textColor;
    if (route) {
      textColor = isSelected ? palette.onHighlight : palette.onAccent;
    } else {
      textColor = isSelected ? palette.text : palette.muted;
    }
    final BoxDecoration? decoration = !isSelected
        ? null
        : switch (style.kind) {
            StyleKind.night => BoxDecoration(
              color: palette.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(style.radius),
            ),
            StyleKind.paper => null,
            StyleKind.route => BoxDecoration(
              color: palette.highlight,
              borderRadius: BorderRadius.circular(style.radiusSmall),
              border: Border.all(color: palette.text, width: 2),
            ),
          };

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: decoration,
        child: Row(
          children: [
            if (style.isPaper)
              SizedBox(
                width: 12,
                child: isSelected
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            Icon(icon, color: textColor, size: 17.6),
            const SizedBox(width: 12.8),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
