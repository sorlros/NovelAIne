# 상태 관리 전략

## 현재 상태 관리 분석

The 현재 구현은 다음을 사용합니다:
- **Riverpod**: 채팅 상태 관리용
- **Simple StateNotifier**: 채팅 메시지와 로딩 상태
- **Provider 패턴**: API 서비스 주입용

## 제안된 상태 관리 아키텍처

### 1. 상태 관리 옵션

#### Riverpod (현재 선택)
**장점:**
- 간단하고 가벼움
- 소규모~중간 규모 앱에 적합
- 보일러플레이트 없음
- 테스트 용이

**단점:**
- 대규모 앱에서 복잡해질 수 있음
- 수동 상태 업데이트
- 기본 제공 지속성 없음

#### Provider + GetIt (대안)
**장점:**
- 더 구조화됨
- 관심사 분리 우수
- 중간 규모 앱에 적합

**단점:**
- 더 많은 보일러플레이트
- 학습 곡선 가파름

#### BLoC (대안)
**장점:**
- 높은 확장성
- 복잡한 앱에 탁월
- 내장 테스트 유틸리티

**단점:**
- 학습 곡선 가파름
- 더 많은 보일러플레이트
- 단순한 앱에는 과도함

#### Redux (대안)
**장점:**
- 예측 가능한 상태 관리
- 대규모 앱에 탁월
- 타임 트래블 디버깅

**단점:**
- 매우 장황함
- 학습 곡선 가파름
- 대부분 앱에는 과도함

## 추천 전략: 하이브리드 접근

### 핵심 원칙
1. **단일 진실 공급원**: 모든 상태 중앙 관리
2. **불변 상태**: 상태 업데이트는 새 인스턴스 생성
3. **예측 가능한 업데이트**: 상태 변경은 추적 가능
4. **성능 최적화**: 효율적인 위젯 재구성

### 상태 관리 계층

#### 1. 서비스 계층 (데이터)
```dart
// 서비스는 데이터 작업 처리
class AuthService {
  // 인증 로직
}

class StoryService {
  // 스토리 CRUD 작업
}

class ChatService {
  // 채팅/AI 생성
}
```

#### 2. 상태 계층 (UI 상태)
```dart
// UI 상태용 상태 알리미
class AuthStateNotifier extends StateNotifier<AuthState> {
  // 인증 상태
}

class StoryStateNotifier extends StateNotifier<StoryState> {
  // 스토리 상태
}

class ChatStateNotifier extends StateNotifier<ChatState> {
  // 채팅 상태
}
```

#### 3. UI 계층 (프레젠테이션)
```dart
// 위젯은 상태 소비
class HomeScreen extends ConsumerWidget {
  // 상태 소비
}

class StoryScreen extends ConsumerWidget {
  // 상태 소비
}
```

## 상태 관리 구현

### 1. 인증 상태
```dart
// 상태 모델
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error ?? this.error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 상태 알리미
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenManager _tokenManager;

  AuthNotifier(this._authService, this._tokenManager)
      : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final hasToken = await _tokenManager.hasValidToken();
    if (hasToken) {
      state = state.copyWith(isAuthenticated: true);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    
    try {
      final result = await _authService.login(email, password);
      await _tokenManager.setAccessToken(result.token);
      state = state.copyWith(
        isAuthenticated: true,
        user: result.user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> logout() async {
    await _tokenManager.clearAccessToken();
    state = const AuthState();
  }
}

// 프로바이더
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  return AuthNotifier(authService, tokenManager);
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final tokenManagerProvider = Provider<TokenManager>((ref) => TokenManager());
```

### 2. 스토리 상태
```dart
// 상태 모델
class StoryState {
  final List<Story> stories;
  final Story? currentStory;
  final bool isLoading;
  final String? error;

  const StoryState({
    this.stories = const [],
    this.currentStory,
    this.isLoading = false,
    this.error,
  });

  StoryState copyWith({
    List<Story>? stories,
    Story? currentStory,
    bool? isLoading,
    String? error,
  }) {
    return StoryState(
      stories: stories ?? this.stories,
      currentStory: currentStory ?? this.currentStory,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// 상태 알리미
class StoryNotifier extends StateNotifier<StoryState> {
  final StoryService _storyService;
  final CacheManager _cacheManager;

  StoryNotifier(this._storyService, this._cacheManager)
      : super(const StoryState());

  Future<void> fetchStories() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final stories = await _cacheManager.getCached(
        'stories',
        () async => await _storyService.getStories(),
      );
      
      state = state.copyWith(
        stories: stories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> createStory(StoryCreationRequest request) async {
    state = state.copyWith(isLoading: true);
    
    try {
      final story = await _storyService.createStory(request);
      final updatedStories = [...state.stories, story];
      
      state = state.copyWith(
        stories: updatedStories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> setCurrentStory(String storyId) async {
    try {
      final story = await _storyService.getStory(storyId);
      state = state.copyWith(currentStory: story);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// 프로바이더
final storyProvider = StateNotifierProvider<StoryNotifier, StoryState>((ref) {
  final storyService = ref.watch(storyServiceProvider);
  final cacheManager = ref.watch(cacheManagerProvider);
  return StoryNotifier(storyService, cacheManager);
});

final storyServiceProvider = Provider<StoryService>((ref) => StoryService());
final cacheManagerProvider = Provider<CacheManager>((ref) => CacheManager());
```

### 3. 채팅 상태
```dart
// 상태 모델
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final bool isTyping;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isTyping = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool? isTyping,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

// 상태 알리미
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;

  ChatNotifier(this._chatService) : super(const ChatState());

  Future<void> sendMessage(String message, {String? storyId}) async {
    final userMessage = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
    );

    try {
      final response = await _chatService.generateStory(
        storyId ?? 'default',
        _generateContext(state.messages),
        message,
        const ChatOptions(temperature: 0.8),
      );

      final aiMessage = ChatMessage(
        role: 'ai',
        content: response.content,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isTyping: false,
      );
    } catch (e) {
      final errorMessage = ChatMessage(
        role: 'system',
        content: 'Error: $e',
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isTyping: false,
        error: e.toString(),
      );
    }
  }

  Future<void> clearChat() async {
    state = const ChatState();
  }

  String _generateContext(List<ChatMessage> messages) {
    // 이전 메시지로부터 컨텍스트 생성
    return messages
        .where((msg) => msg.role != 'system')
        .map((msg) => '${msg.role}: ${msg.content}')
        .join('\n');
  }
}

// 프로바이더
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ChatNotifier(chatService);
});

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
```

## 상태 관리 패턴

### 1. 프로바이더 패턴
```dart
// 간단한 프로바이더
final userProvider = StateProvider<User>>((ref) => null);

// 상태 알리미 프로바이더
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// 퓨처 프로바이더
final storiesProvider = FutureProvider<List<Story>>((ref) async {
  final service = ref.watch(storyServiceProvider);
  return await service.getStories();
});
```

### 2. 컨슈머 위젯
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final stories = ref.watch(storiesProvider);

    return Scaffold(
      body: authState.when(
        data: (state) {
          if (state.isAuthenticated) {
            return stories.when(
              data: (stories) => StoriesView(stories: stories),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorView(error: error),
            );
          } else {
            return const AuthView();
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorView(error: error.toString()),
      ),
    );
  }
}
```

### 3. 상태 접근 패턴

#### 직접 접근
```dart
// 위젯에서
final state = ref.watch(provider);

// 서비스에서
final state = ref.read(provider).state;
```

#### 파생 상태
```dart
// 성능을 위한 select 사용
final unreadCount = ref.select(notificationProvider, (value) => 
  value.messages.where((msg) => !msg.isRead).length
);

// computed 사용
final activeStories = ref.watch(storiesProvider).where((story) => 
  story.status == 'active'
);
```

## 성능 최적화

### 1. 선택적 업데이트
```dart
// 특정 부분만 변경될 때 재구성
final unreadCount = ref.select(notificationProvider, (value) => 
  value.messages.where((msg) => !msg.isRead).length
);
```

### 2. 캐시 관리
```dart
// 캐시 프로바이더
final cachedStoriesProvider = FutureProvider.autoDispose<List<Story>>((
  ref,
) async {
  final cacheKey = 'stories_cache';
  final cache = ref.read(cacheManagerProvider);
  
  return await cache.getOrFetch(
    cacheKey,
    () async => await ref.watch(storyServiceProvider).getStories(),
    Duration(minutes: 5),
  );
});
```

### 3. 메모리 관리
```dart
// 자동 해제 프로바이더
final autoDisposeStoriesProvider = FutureProvider.autoDispose<List<Story>>((
  ref,
) async {
  final service = ref.watch(storyServiceProvider);
  return await service.getStories();
});
```

## 테스트 전략

### 1. 단위 테스트
```dart
void main() {
  group('AuthNotifier', () {
    late AuthNotifier notifier;
    late MockAuthService mockService;

    setUp(() {
      mockService = MockAuthService();
      notifier = AuthNotifier(mockService, MockTokenManager());
    });

    test('should login successfully', () async {
      when(mockService.login('test@test.com', 'password'))
          .thenAnswer((_) async => AuthResponse('token', User('test')));

      await notifier.login('test@test.com', 'password');

      expect(notifier.state.isAuthenticated, true);
      expect(notifier.state.user?.email, 'test@test.com');
    });
  });
}
```

### 2. 위젯 테스트
```dart
void main() {
  group('HomeScreen', () {
    testWidgets('should show loading when fetching stories', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

## 다음 단계
1. 인증 상태 관리 구현
2. 스토리 상태 관리 추가
3. 채팅 상태 관리 강화
4. 캐싱과 성능 최적화 추가
5. 포괄적인 테스트 구현
6. 상태 관리 패턴 문서화

---
*문서 생성일: 2026-03-05*
*프론트엔드 개발자: [Your Name]*
*상태 관리 전략: Riverpod 기반 하이브리드 접근*