import 'package:flutter/material.dart';
import 'side_menu.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final Widget? bottomNavigationBar;

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                SideMenu(currentIndex: currentIndex),
                Expanded(
                  // Hide the bottom navigation bar on desktop by not passing it
                  child: child,
                ),
              ],
            ),
          );
        } else {
          // Mobile/Tablet: Show Content + Bottom Navigation Bar
          if (bottomNavigationBar != null) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: child,
              bottomNavigationBar: bottomNavigationBar,
            );
          }
          return child;
        }
      },
    );
  }
}
