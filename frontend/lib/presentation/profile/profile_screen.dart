import 'package:flutter/material.dart';
import 'package:frontend/data/services/api_service.dart';
import '../screens/auth/auth_screen.dart';
import 'widgets/user_header_widget.dart';
import 'widgets/my_library_tab.dart';
import 'widgets/my_creations_tab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (!mounted) return;

    // Auth Flow: Navigate back to AuthScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep dark background
      appBar: AppBar(
        title: const Text(
          "내 프로필",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. User Information Header
          const UserHeaderWidget(),

          const SizedBox(height: 24),

          // 2. Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Slightly lighter background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF7C3AED), // Vibrant purple
                borderRadius: BorderRadius.circular(16),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(text: "내 서재"),
                Tab(text: "나의 창작물"),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [MyLibraryTab(), MyCreationsTab()],
            ),
          ),
        ],
      ),
    );
  }
}
