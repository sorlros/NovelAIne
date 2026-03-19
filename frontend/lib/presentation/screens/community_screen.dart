import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/crisp_bottom_nav_bar.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('커뮤니티'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined, size: 80, color: Colors.white24),
              const SizedBox(height: 24),
              Text(
                "독자 및 작가들과 의견을 나누고\n세계관을 공유하는 공간입니다.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  "곧 출시 예정",
                  style: TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MediaQuery.of(context).size.width < 900 
            ? const CrispBottomNavBar(currentIndex: 3)
            : null,
      ),
    );
  }
}
