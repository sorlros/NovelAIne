import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/community_screen.dart';
import '../screens/vault/vault_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../screens/creation/mode_selection_screen.dart' as creation_screen;

class CrispBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const CrispBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarIcon(
                    iconOutlined: Icons.home_outlined, 
                    iconSolid: Icons.home, 
                    isSelected: currentIndex == 0, 
                    onTap: () => _navigateTo(context, 0),
                  ),
                  _NavBarIcon(
                    iconOutlined: Icons.add_circle_outline, 
                    iconSolid: Icons.add_circle, 
                    isSelected: currentIndex == 1, 
                    onTap: () => _navigateTo(context, 1),
                  ),
                  _NavBarIcon(
                    iconOutlined: Icons.archive_outlined, 
                    iconSolid: Icons.archive, 
                    isSelected: currentIndex == 2, 
                    onTap: () => _navigateTo(context, 2),
                  ),
                  _NavBarIcon(
                    iconOutlined: Icons.settings_outlined, 
                    iconSolid: Icons.settings, 
                    isSelected: currentIndex == 3, 
                    onTap: () => _navigateTo(context, 3),
                  ),
                  _NavBarIcon(
                    iconOutlined: Icons.person_outline, 
                    iconSolid: Icons.person, 
                    isSelected: currentIndex == 4, 
                    onTap: () => _navigateTo(context, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        screen = const CharacterVaultScreen();
        break;
      case 3:
        screen = const SettingsScreen(); // From side menu mapping
        break;
      case 4:
        screen = const ProfileScreen();
        break;
      default:
        screen = const HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => screen,
        transitionDuration: Duration.zero,
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  final IconData iconOutlined;
  final IconData iconSolid;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarIcon({
    required this.iconOutlined, 
    required this.iconSolid, 
    required this.isSelected, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Icon(
            isSelected ? iconSolid : iconOutlined,
            color: isSelected ? const Color(0xFF7C3AED) : Colors.white54,
            size: 24,
          ),
        ),
      ),
    );
  }
}
