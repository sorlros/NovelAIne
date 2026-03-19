import 'package:flutter/material.dart';
import 'side_menu.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final Widget? bottomNavigationBar; // Keep for backward compatibility, but discourage nesting

  const ResponsiveLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          // Desktop: Show Sidebar + Content
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Row(
              children: [
                SideMenu(currentIndex: currentIndex),
                Expanded(
                  child: child,
                ),
              ],
            ),
          );
        } else {
          // Mobile/Tablet: Just show the child.
          // The child (e.g. HomeScreen) should manage its own Scaffold and BottomNavBar.
          return child;
        }
      },
    );
  }
}
