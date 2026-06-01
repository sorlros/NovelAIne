import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.value;

    return ResponsiveLayout(
      currentIndex: 4,
      appBar: AppBar(
        title: const Text("설정 및 프로필"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(
                    0xFF7C3AED,
                  ).withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: Color(0xFF7C3AED),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                  user?.username ?? "사용자",
                  style: GoogleFonts.notoSerif(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.email ?? "",
                  style: GoogleFonts.lato(fontSize: 16, color: Colors.white54),
                ),
                const SizedBox(height: 48),
                _buildMenuItem(
                  icon: Icons.edit_outlined,
                  title: "회원 정보 수정",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: "알림 설정",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.security_rounded,
                  title: "보안 및 개인정보",
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: "고객 센터",
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
