import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_palette.dart';
import '../../widgets/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../auth/auth_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
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
            icon: Icon(Icons.logout_rounded, color: palette.danger),
            onPressed: () async {
              // The login screen opens home for a signed-in user: sign out first.
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
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
                  backgroundColor: palette.accent.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: palette.accent,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                  user?.username ?? "사용자",
                  style: GoogleFonts.notoSerif(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                ),
                Text(
                  user?.email ?? "",
                  style: GoogleFonts.lato(fontSize: 16, color: palette.muted),
                ),
                const SizedBox(height: 48),
                _buildMenuItem(
                  palette: palette,
                  icon: Icons.palette_outlined,
                  title: "화면 테마",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeScreen(),
                    ),
                  ),
                ),
                _buildMenuItem(
                  palette: palette,
                  icon: Icons.edit_outlined,
                  title: "회원 정보 수정",
                  onTap: () {},
                ),
                _buildMenuItem(
                  palette: palette,
                  icon: Icons.notifications_none_rounded,
                  title: "알림 설정",
                  onTap: () {},
                ),
                _buildMenuItem(
                  palette: palette,
                  icon: Icons.security_rounded,
                  title: "보안 및 개인정보",
                  onTap: () {},
                ),
                _buildMenuItem(
                  palette: palette,
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
    required AppPalette palette,
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
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: palette.accent, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: palette.faint,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
