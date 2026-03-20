import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'side_menu.dart';
import 'crisp_bottom_nav_bar.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color backgroundColor;
  final bool showBottomNav;
  final bool extendBodyBehindAppBar;

  const ResponsiveLayout({
    super.key,
    required this.body,
    required this.currentIndex,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor = const Color(0xFF121212),
    this.showBottomNav = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;

        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          appBar: isDesktop ? null : appBar,
          body: KeyedSubtree(
            key: ValueKey(isDesktop),
            child: isDesktop
                ? Row(
                    children: [
                      SideMenu(currentIndex: currentIndex),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: (!isDesktop && showBottomNav)
              ? CrispBottomNavBar(currentIndex: currentIndex)
              : null,
        );
      },
    );
  }
}
