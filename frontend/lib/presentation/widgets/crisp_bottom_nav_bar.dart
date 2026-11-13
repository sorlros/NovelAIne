import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_style.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/vault/vault_screen.dart';
import '../profile/profile_screen.dart';
import '../screens/creation/mode_selection_screen.dart' as creation_screen;

class CrispBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const CrispBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height:
          64 + bottomInset, // room for icon and label above the system inset
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: style.edge(palette), width: style.borderWidth),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
          ), // Reduced from 800 for better mobile fit
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarIcon(
                iconOutlined: Icons.home_outlined,
                iconSolid: Icons.home,
                label: '서재',
                isSelected: currentIndex == 0,
                onTap: () => _navigateTo(context, 0),
              ),
              _NavBarIcon(
                iconOutlined: Icons.explore_outlined,
                iconSolid: Icons.explore,
                label: '탐색',
                isSelected: currentIndex == 1,
                onTap: () => _navigateTo(context, 1),
              ),
              _NavBarIcon(
                iconOutlined: Icons.add_circle_outline,
                iconSolid: Icons.add_circle,
                label: '만들기',
                isSelected: currentIndex == 2,
                onTap: () => _navigateTo(context, 2),
              ),
              _NavBarIcon(
                iconOutlined: Icons.archive_outlined,
                iconSolid: Icons.archive,
                label: '보관함',
                isSelected: currentIndex == 3,
                onTap: () => _navigateTo(context, 3),
              ),
              _NavBarIcon(
                iconOutlined: Icons.person_outline,
                iconSolid: Icons.person,
                label: '내 정보',
                isSelected: currentIndex == 4,
                onTap: () => _navigateTo(context, 4),
              ),
            ],
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarIcon({
    required this.iconOutlined,
    required this.iconSolid,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.appStyle;
    final route = style.isRoute;
    final paper = style.isPaper;
    final Color color = isSelected
        ? (paper
              ? palette.text
              : (route ? palette.onHighlight : palette.accent))
        : palette.muted;
    final labelColor = isSelected
        ? (paper || route ? palette.text : palette.accent)
        : palette.muted;
    Widget icon = Icon(
      isSelected ? iconSolid : iconOutlined,
      color: color,
      size: 24,
    );
    if (route && isSelected) {
      icon = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: palette.highlight,
          borderRadius: BorderRadius.circular(style.radiusSmall),
          border: Border.all(color: palette.text, width: 2),
        ),
        child: icon,
      );
    }
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Stack(
            children: [
              if (paper && isSelected)
                Positioned(
                  top: 0,
                  left: 8,
                  right: 8,
                  child: Container(height: 2, color: palette.accent),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: labelColor,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
