# API 서비스 계층 구조 설계

## 현재 서비스 분석

현재 `ApiService` 클래스가 제공하는 기능:
- 인증 (로그인, 회원가입, 로그아웃)
- 채팅 기능 (AI 스토리 생성)
- 스토리 관리 (조회, 생성)
- 장면 생성

## 제안된 아키텍처

### 1. 서비스 계층 구성

```
data/services/
├── api_service.dart              # 메인 API 서비스
├── auth_service.dart            # 인증
├── story_service.dart           # 스토리 관리
├── chat_service.dart            # 채팅/AI 생성
├── scene_service.dart           # 장면 관리
├── character_service.dart       # 캐릭터 관리
└── file_service.dart            # 파일 업로드/다운로드
```

### 2. 서비스 인터페이스 설계

#### 베이스 서비스 클래스
```dart
abstract class BaseService {
  final String _baseUrl;
  final http.Client _client;

  BaseService(this._baseUrl, this._client);

  Future<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
  );

  Future<T> _get<T>(String endpoint, {
    Map<String, String> headers = const {},
    T Function(Map<String, dynamic>) parser,
  });

  Future<T> _post<T>(String endpoint, dynamic body, {
    Map<String, String> headers = const {},
    T Function(Map<String, dynamic>) parser,
  });

  Future<T> _put<T>(String endpoint, dynamic body, {
    Map<String, String> headers = const {},
    T Function(Map<String, dynamic>) parser,
  });

  Future<T> _delete<T>(String endpoint, {
    Map<String, String> headers = const {},
    T Function(Map<String, dynamic>) parser,
  });
}
```

#### 인증 서비스
```dart
class AuthService {
  // 로그인
  Future<AuthResponse> login(String email, String password);

  // 회원가입
  Future<AuthResponse> signup(String email, String password, String username);

  // 로그아웃
  Future<void> logout();

  // 토큰 관리
  Future<String> getAccessToken();
  Future<void> setAccessToken(String token);
  Future<void> clearAccessToken();

  // 사용자 프로필
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(UserProfile profile);
}
```

#### 스토리 서비스
```dart
class StoryService {
  // 모든 스토리 조회
  Future<List<Story>> getStories({
    int limit = 20,
    int offset = 0,
    String? genre,
    String? status,
  });

  // 단일 스토리 조회
  Future<Story> getStory(String storyId);

  // 스토리 생성
  Future<Story> createStory(StoryCreationRequest request);

  // 스토리 업데이트
  Future<Story> updateStory(String storyId, StoryUpdateRequest request);

  // 스토리 삭제
  Future<void> deleteStory(String storyId);

  // 스토리 챕터 조회
  Future<List<Chapter>> getChapters(String storyId);

  // 스토리 장면 조회
  Future<List<Scene>> getScenes(String storyId);
}
```

#### 채팅 서비스
```dart
class ChatService {
  // 스토리 계속 생성
  Future<ChatResponse> generateStory(
    String storyId,
    String context,
    String userInput,
    ChatOptions options,
  );

  // 캐릭터 대화 생성
  Future<ChatResponse> generateDialogue(
    String storyId,
    String characterName,
    String context,
    String userInput,
  );

  // 채팅 기록 조회
  Future<List<ChatMessage>> getChatHistory(String storyId);

  // 채팅 기록 삭제
  Future<void> clearChatHistory(String storyId);
}
```

#### 장면 서비스
```dart
class SceneService {
  // 장면 생성
  Future<Scene> createScene(SceneCreationRequest request);

  // 장면 조회
  Future<Scene> getScene(String sceneId);

  // 장면 업데이트
  Future<Scene> updateScene(String sceneId, SceneUpdateRequest request);

  // 장면 삭제
  Future<void> deleteScene(String sceneId);

  // 스토리별 장면 조회
  Future<List<Scene>> getScenesByStory(String storyId);

  // 챕터별 장면 조회
  Future<List<Scene>> getScenesByChapter(String chapterId);
}
```

### 3. 요청/응답 모델

#### 베이스 응답 모델
```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse._({this.success = false, this.data, this.error});

  factory ApiResponse.ok(T data) {
    return ApiResponse<T>._(success: true, data: data);
  }

  factory ApiResponse.fail(String error) {
    return ApiResponse<T>._(success: false, error: error);
  }

  bool get hasError = success == false;
}
```

#### 인증 모델
```dart
class AuthRequest {
  final String email;
  final String password;
  final String? username;

  AuthRequest({
    required this.email,
    required this.password,
    this.username,
  });

  Map<String, String> toJson() {
    return {
      'email': email,
      'password': password,
      'username': username,
    };
  }
}

class AuthResponse {
  final String token;
  final UserProfile user;

  AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: UserProfile.fromJson(json['user']),
    );
  }
}
```

#### 스토리 모델
```dart
class StoryCreationRequest {
  final String title;
  final String genre;
  final String tone;
  final String protagonistName;
  final List<String> protagonistTraits;
  final String? openingScenario;

  StoryCreationRequest({
    required this.title,
    required this.genre,
    required this.tone,
    required this.protagonistName,
    required this.protagonistTraits,
    this.openingScenario,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'genre': genre,
      'tone': tone,
      'protagonist_name': protagonistName,
      'protagonist_traits': protagonistTraits,
      'opening_scenario': openingScenario,
    };
  }
}

class StoryUpdateRequest {
  final String? title;
  final String? genre;
  final String? status;
  final String? description;

  StoryUpdateRequest({
    this.title,
    this.genre,
    this.status,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
      if (description != null) 'description': description,
    };
  }
}
```

### 4. 에러 처리 전략

#### 커스텀 예외
```dart
class ApiRequestException implements Exception {
  final String message;
  final int? statusCode;

  ApiRequestException(this.message, {this.statusCode});

  @override
  String toString() {
    return 'ApiRequestException: $message (status: $statusCode)';
  }
}

class AuthenticationException implements Exception {
  final String message;

  AuthenticationException(this.message);

  @override
  String toString() {
    return 'AuthenticationException: $message';
  }
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() {
    return 'NetworkException: $message';
  }
}
```

#### 서비스에서의 에러 처리
```dart
class StoryService {
  Future<List<Story>> getStories() async {
    try {
      final response = await _get<List<Story>>(
        '/stories',
        parser: (json) => (json['data'] as List)
            .map((item) => Story.fromJson(item))
            .toList(),
      );
      
      return response;
    } on ApiRequestException catch (e) {
      if (e.statusCode == 401) {
        throw AuthenticationException('Unauthorized');
      }
      throw e;
    } on SocketException catch (_) {
      throw NetworkException('No internet connection');
    }
  }
}
```

### 5. 캐싱 전략

#### 캐시 매니저
```dart
class CacheManager {
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimes = {};
  final Duration _defaultCacheDuration = Duration(minutes: 5);

  Future<T> getCached<T>(String key, Future<T> Function() fetcher) async {
    final cached = _cache[key];
    final cacheTime = _cacheTimes[key];
    
    if (cached != null && 
        cacheTime != null && 
        cacheTime.add(_defaultCacheDuration).isAfter(DateTime.now())) {
      return cached as T;
    }
    
    final result = await fetcher();
    _cache[key] = result;
    _cacheTimes[key] = DateTime.now();
    
    return result;
  }

  void clearCache(String key) {
    _cache.remove(key);
    _cacheTimes.remove(key);
  }

  void clearAllCache() {
    _cache.clear();
    _cacheTimes.clear();
  }
}
```

#### 서비스 연동
```dart
class StoryService {
  final CacheManager _cacheManager = CacheManager();

  Future<List<Story>> getStories() {
    return _cacheManager.getCached(
      'stories',
      () async {
        final response = await _get<List<Story>>('/stories');
        return response;
      },
    );
  }

  Future<Story> getStory(String storyId) {
    return _cacheManager.getCached(
      'story_$storyId',
      () async {
        final response = await _get<Story>('/stories/$storyId');
        return response;
      },
    );
  }
}
```

### 6. 토큰 관리

#### 보안 저장소
```dart
class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<String> getAccessToken() async {
    // flutter_secure_storage 사용 구현
  }

  Future<void> setAccessToken(String token) async {
    // flutter_secure_storage 사용 구현
  }

  Future<void> clearAccessToken() async {
    // flutter_secure_storage 사용 구현
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && !isTokenExpired(token);
  }

  bool isTokenExpired(String token) {
    // JWT 토큰 만료 확인
  }
}
```

#### 자동 토큰 갱신
```dart
class AuthService {
  Future<String> getValidToken() async {
    final tokenManager = TokenManager();
    
    if (await tokenManager.hasValidToken()) {
      return tokenManager.getAccessToken();
    }
    
    // 토큰 갱신 시도
    try {
      final refreshedToken = await _refreshToken();
      await tokenManager.setAccessToken(refreshedToken);
      return refreshedToken;
    } catch (e) {
      throw AuthenticationException('Token refresh failed');
    }
  }
}
```

### 7. 서비스 사용 예시

#### 인증 흐름
```dart
class AuthService {
  final AuthService _authService = AuthService();
  
  Future<void> loginAndNavigate(String email, String password) async {
    try {
      final response = await _authService.login(email, password);
      // 토큰 안전하게 저장
      await TokenManager().setAccessToken(response.token);
      // 홈으로 이동
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }
}
```

#### 스토리 관리
```dart
class StoryService {
  final StoryService _storyService = StoryService();
  
  Future<void> createStoryAndNavigate(StoryCreationRequest request) async {
    try {
      final story = await _storyService.createStory(request);
      // 스토리 화면으로 이동
      Navigator.pushNamed(context, '/story', arguments: story.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story creation failed: $e')),
      );
    }
  }
}
```

## 다음 단계
1. 베이스 서비스 클래스 구현
2. 개별 서비스 클래스 생성
3. 에러 처리와 캐싱 추가
4. 토큰 관리 구현
5. 포괄적인 테스트 추가
6. UI 컴포넌트와 연동

---
*문서 생성일: 2026-03-05*
*프론트엔드 개발자: [Your Name]*
*API 서비스 아키텍처: 모듈화되고 확장 가능한 구조*