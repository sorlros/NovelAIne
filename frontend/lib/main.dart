import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/l10n/app_localizations.dart';
import 'core/constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'data/local/app_database.dart';
import 'data/repositories/story_repository.dart';
import 'data/services/api_service.dart';

void main() async {
  // 1. Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. [성능 최적화] 엔진 및 서버 예열 (Pre-warming)
  final database = AppDatabase();
  final apiService = ApiService();
  final repository = StoryRepository(
    apiService: apiService,
    database: database,
  );

  // 서버와 로컬 DB를 미리 활성화합니다.
  Future<void>(() async {
    await Future.wait<Object>([
      http
          .get(Uri.parse(AppConstants.baseUrl.replaceFirst('/api', '')))
          .catchError((_) => http.Response('', 500)),
      database.select(database.stories).get().catchError((_) => <Story>[]),
    ]);
  });

  runApp(
    ProviderScope(
      overrides: [
        // 앱 전역에서 미리 예열된 인스턴스를 사용하도록 강제 설정
        storyRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovelAIne',
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
