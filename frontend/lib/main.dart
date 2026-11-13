import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/l10n/app_localizations.dart';
import 'core/constants.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'data/local/app_database.dart';
import 'data/repositories/story_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/theme_store.dart';
import 'presentation/providers/theme_provider.dart';

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

  // Read before the first frame, so the app does not open in another theme and then switch.
  final savedTheme = await ThemeStore().read();

  runApp(
    ProviderScope(
      overrides: [
        // 앱 전역에서 미리 예열된 인스턴스를 사용하도록 강제 설정
        storyRepositoryProvider.overrideWithValue(repository),
        themeChoiceProvider.overrideWith((ref) => ThemeChoice(savedTheme)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    // One theme for both modes, unless the reader follows the device.
    final picked = choice == followDevice
        ? null
        : AppThemeId.values.byName(choice);
    return MaterialApp(
      title: 'NovelAIne',
      theme: AppTheme.of(picked ?? AppThemeId.wongoji),
      darkTheme: AppTheme.of(picked ?? AppThemeId.simya),
      themeMode: ThemeMode.system,
      // AppLocalizations.localizationsDelegates still lists flutter_localizations' delegates.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
