import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
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
        screen = const creation_screen.CreationModeSelectionScreen();
        break;
      case 2:
        screen = const ExploreScreen(); // Placeholder for settings
        break;
      case 3:
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
    return Container(
      width: 250,
      color: const Color(0xFF0D0D12), // Darker background to match image
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.auto_stories, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  "NovelAIne",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
            icon: Icons.edit,
            title: "창작하기",
            isSelected: currentIndex == 1,
            onTap: () => _navigateTo(context, 1),
          ),
          _SideMenuItem(
            icon: Icons.settings,
            title: "설정",
            isSelected: currentIndex == 2,
            onTap: () => _navigateTo(context, 2),
          ),
          const Spacer(),
          const Divider(color: Colors.white10, height: 1),
          _SideMenuItem(
            icon: Icons.person_outline,
            title: "내 프로필",
            isSelected: currentIndex == 3,
            onTap: () => _navigateTo(context, 3),
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
    const primaryColor = Color(0xFF3F3B6C); // Matches selected background in image
    const textColor = Colors.white;
    const textSecondary = Colors.white54;

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
