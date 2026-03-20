import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isLogin = _tabController.index == 0;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    // 1. 공통 유효성 검사
    if (email.isEmpty) {
      _showError("이메일을 입력해주세요.");
      return;
    }
    if (password.isEmpty) {
      _showError("비밀번호를 입력해주세요.");
      return;
    }

    // 2. 한국어 포함 여부 검사 (아이디/이메일에 한국어 금지)
    final koreanRegex = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]');
    if (koreanRegex.hasMatch(email)) {
      _showError("아이디(이메일)에 한국어를 포함할 수 없습니다.");
      return;
    }

    // 3. 이메일 형식 검사 (간단한 정규식)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showError("유효한 이메일 형식이 아닙니다.");
      return;
    }

    // 4. 회원가입 시 추가 검사
    if (!isLogin) {
      if (username.isEmpty) {
        _showError("사용자 이름을 입력해주세요.");
        return;
      }
      if (password.length < 6) {
        _showError("비밀번호는 최소 6자 이상이어야 합니다.");
        return;
      }
    }

    if (isLogin) {
      await ref.read(authProvider.notifier).login(email, password);
    } else {
      await ref.read(authProvider.notifier).signup(email, password, username);
    }

    final authState = ref.read(authProvider);
    if (authState.hasValue && authState.value != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (authState.hasError) {
      if (!mounted) return;
      _showError("${authState.error}");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 800) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF151515),
                            const Color(0xFF0D0D12),
                            const Color(0xFF6B4EFF).withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_stories, color: Colors.white, size: 80),
                            SizedBox(height: 24),
                            Text(
                              "NovelAIne",
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "당신의 상상력이 현실이 되는 곳",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: _buildFormCard(isLoading),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_stories, color: Colors.white, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          "NovelAIne",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildFormCard(isLoading),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  controller: _emailController,
                  label: AppLocalizations.of(context)!.email,
                  icon: Icons.email_outlined,
                  textInputAction: TextInputAction.next,
                ),
                ValueListenableBuilder(
                  valueListenable: _tabController.animation!,
                  builder: (context, anim, child) {
                    if (_tabController.index == 1 || anim > 0.5) {
                      return Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildField(
                            controller: _usernameController,
                            label: AppLocalizations.of(context)!.username,
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _passwordController,
                  label: AppLocalizations.of(context)!.password,
                  icon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: isLoading ? null : (_) => _submit(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _tabController.index == 0
                                ? AppLocalizations.of(context)!.login
                                : AppLocalizations.of(context)!.signup,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: Color(0xFF6B4EFF), width: 3),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        tabs: [
          Tab(text: AppLocalizations.of(context)!.login),
          Tab(text: AppLocalizations.of(context)!.signup),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54, size: 20),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6B4EFF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
