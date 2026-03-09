# Flutter 의존성 분석

## 현재 의존성

### 핵심 의존성
```yaml
flutter:
  sdk: flutter
```

### UI/UX 의존성
- **cupertino_icons: ^1.0.8** - iOS 스타일 아이콘
- **google_fonts: ^6.1.0** - Google Fonts 연동
- **flutter_animate: ^4.5.0** - 애니메이션 유틸리티
- **animated_text_kit: ^4.2.2** - 애니메이션 텍스트 효과

### 개발 의존성
- **flutter_lints: ^6.0.0** - 코드 린트
- **flutter_test: sdk: flutter** - 테스트 프레임워크

### API & 데이터 의존성
- **http: ^1.1.0** - API 호출용 HTTP 클라이언트
- **uuid: ^4.2.1** - UUID 생성

### 상태 관리
- **flutter_riverpod: ^2.4.9** - 상태 관리 라이브러리

### 콘텐츠 처리
- **flutter_markdown: ^0.6.18** - 마크다운 렌더링

## 백엔드 연동 요구사항

### 필요한 백엔드 의존성
백엔드 분석을 바탕으로 추가해야 할 의존성:

```yaml
dependencies:
  # JSON 직렬화
  json_annotation: ^4.7.1
  json_serializable: ^6.7.1

  # HTTP 클라이언트 (더 나은 옵션 필요 시)
  dio: ^5.3.4

  # 상태 관리 (대안 필요 시)
  provider: ^6.1.1
  get_it: ^7.6.4

  # 인증
  flutter_secure_storage: ^9.0.0
  jwt_decoder: ^2.0.0

  # 이미지 처리
  cached_network_image: ^3.4.0
  image_picker: ^1.0.0

  # 캐싱
  hive: ^2.1.0
  hive_flutter: ^2.1.0

  # 로깅
  logger: ^2.0.0
```

## 아키텍처별 의존성

### Riverpod 상태 관리용
```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  hooks_riverpod: ^2.4.9
  flutter_hooks: ^1.0.0
```

### Provider 상태 관리용
```yaml
dependencies:
  provider: ^6.1.1
  get_it: ^7.6.4
```

## 백엔드 통신 의존성

### HTTP 클라이언트 옵션
- **http**: 기본 HTTP 클라이언트 (현재)
- **dio**: 인터셉터 지원하는 더 강력한 HTTP 클라이언트
- **chopper**: HTTP 클라이언트 생성기

### 데이터 직렬화
- **json_annotation**: JSON용 코드 생성
- **json_serializable**: JSON 직렬화
- **freezed**: 불변 데이터 클래스

## 추천 추가 사항

### 보안
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  cryptography: ^3.0.0
```

### 성능
```yaml
dependencies:
  cached_network_image: ^3.4.0
  shimmer: ^2.0.0
```

### 개발 도구
```yaml
dependencies:
  devtools: ^2.0.0
  lint: ^2.0.0
```

## 버전 호환성

### 현재 버전
- Flutter SDK: ^3.10.7
- Dart SDK: Flutter SDK와 호환

### 추천 업데이트
```yaml
# 기존 의존성 업데이트
dependencies:
  flutter_riverpod: ^2.4.9  # 현재 유지
  http: ^1.1.0            # 현재 유지
  
  # 업데이트 고려
  cupertino_icons: ^1.0.8  # 현재 유지
  google_fonts: ^6.1.0    # 현재 유지
```

## 백엔드와 연동

### API 서비스 계층
```dart
// 현재 구조
class ApiService {
  final http.Client client;
  
  Future<dynamic> get(String endpoint) async {
    final response = await client.get(Uri.parse(endpoint));
    return json.decode(response.body);
  }
}
```

### 상태 관리와 API 호출
```dart
// Riverpod 예시
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(http.Client());
});

final storiesProvider = FutureProvider.autoDispose<List<Story>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.get('/api/stories');
});
```

## 다음 단계
1. 백엔드 팀과 현재 의존성 검토
2. 누락된 백엔드 연동 의존성 추가
3. 버전 호환성 업데이트
4. 개발 도구 추가
5. 의존성 선택 문서화

---
*문서 생성일: 2026-03-05*
*프론트엔드 개발자: [Your Name]*
*백엔드 협업: 필요*