# UI 컴포넌트 구조 설계

## 현재 컴포넌트 분석

### 화면 개요
1. **HomeScreen** - 메인 대시보드와 스토리 라이브러리
2. **StoryScreen** - 인터랙티브 스토리 읽기/채팅 인터페이스
3. **ProfileScreen** - 사용자 프로필 및 라이브러리 관리
4. **AuthScreen** - 인증 흐름
5. **WizardScreen** - 스토리 생성 마법사
6. **ChatScreen** - 전용 채팅 인터페이스
7. **CharacterSheetWidget** - 캐릭터 정보 표시

### 기존 위젯
1. **_HeaderSection** - 앱 헤더와 네비게이션
2. **_ContinueReadingCard** - 스토리 미리보기 카드
3. **_LibraryGrid** - 스토리 그리드 레이아웃
4. **_CustomBottomNavBar** - 바텀 네비게이션
5. **_NavBarIcon** - 네비게이션 바 아이콘
6. **_NarrativeText** - AI 생성 스토리 텍스트
7. **_UserAction** - 사용자 입력 표시
8. **_CommandBar** - 입력 필드와 전송 버튼

## 제안된 컴포넌트 아키텍처

### 1. 아토믹 디자인 시스템
```
components/
├── atoms/
│   ├── buttons/
│   │   ├── primary_button.dart
│   │   ├── secondary_button.dart
│   │   └── icon_button.dart
│   ├── text_fields/
│   │   ├── standard_text_field.dart
│   │   └── search_text_field.dart
│   ├── cards/
│   │   ├── story_card.dart
│   │   ├── character_card.dart
│   │   └── info_card.dart
│   ├── icons/
│   │   ├── custom_icon.dart
│   │   └── animated_icon.dart
│   └── text/
│       ├── body_text.dart
│       ├── title_text.dart
│       └── subtitle_text.dart
├── molecules/
│   ├── navigation/
│   │   ├── bottom_nav_bar.dart
│   │   └── side_nav_menu.dart
│   ├── forms/
│   │   ├── login_form.dart
│   │   └── search_bar.dart
│   ├── story/
│   │   ├── story_preview.dart
│   │   └── story_metadata.dart
│   └── chat/
│       ├── message_bubble.dart
│       └── typing_indicator.dart
├── organisms/
│   ├── story_library/
│   │   ├── story_grid.dart
│   │   └── story_list.dart
│   ├── chat_interface/
│   │   ├── chat_view.dart
│   │   └── input_bar.dart
│   └── profile/
│       ├── profile_header.dart
│       └── profile_stats.dart
└── templates/
    ├── dashboard_template.dart
    ├── story_template.dart
    └── profile_template.dart
```

### 2. 컴포넌트 카테고리

#### 아토믹 컴포넌트 (Atoms)
- **Buttons**: Primary, Secondary, Icon, Floating
- **Text Fields**: Standard, Search, Password
- **Cards**: Story, Character, Info, Action
- **Icons**: Custom, Animated, Status
- **Text**: Body, Title, Subtitle, Caption

#### 분자 컴포넌트 (Molecules)
- **Navigation**: Bottom Nav, Side Menu, Tab Bar
- **Forms**: Login, Search, Filter
- **Story**: Preview, Metadata, Cover
- **Chat**: Message Bubble, Typing Indicator, Status

#### 유기체 컴포넌트 (Organisms)
- **Story Library**: Grid, List, Filter
- **Chat Interface**: View, Input, History
- **Profile**: Header, Stats, Tabs
- **Creation**: Wizard, Steps, Review

### 3. 화면 구조 개선

#### HomeScreen 리팩토링
```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardTemplate(
      header: const AppHeader(
        title: 'NovelAIne',
        actions: [ProfileButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ContinueReadingSection(),
            const SizedBox(height: 32),
            const LibrarySection(),
          ],
        ),
      ),
      bottomNav: const BottomNavBar(
        currentIndex: 0,
        onTabTapped: (index) => _handleTabTap(index),
      ),
      floatingActionButton: const FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _createStory,
      ),
    );
  }
}
```

#### StoryScreen 리팩토링
```dart
class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key});

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  @override
  Widget build(BuildContext context) {
    return ChatTemplate(
      appBar: const ChatAppBar(
        title: 'Story Title',
        actions: [
          CharacterSheetButton(),
          MenuButton(),
        ],
      ),
      body: const ChatView(
        messages: messages,
        isLoading: isLoading,
      ),
      inputBar: const InputBar(
        controller: controller,
        onSend: sendMessage,
      ),
    );
  }
}
```

## 컴포넌트 설계 원칙

### 1. 재사용성
- 각 컴포넌트는 여러 상황에서 사용 가능해야 함
- Props는 다양한 사용 사례에 맞게 설정 가능해야 함
- 하드코딩된 값 피하기

### 2. 일관성
- Material Design 가이드라인 따르기
- 일관된 색상 스킴과 타이포그래피 사용
- 간격과 레이아웃 패턴 유지

### 3. 접근성
- 스크린 리더 지원
- 충분한 명암비 제공
- 적절한 크기의 터치 타겟 포함

### 4. 성능
- 부드러운 애니메이션 최적화
- 적절한 곳에 지연 로딩 구현
- 위젯 재구성 최소화

## 상태 관리 연동

### Provider 연동
```dart
// 상태 관리용 컴포넌트
final storyListProvider = StateNotifierProvider<StoryListNotifier, AsyncValue<List<Story>>>((
  ref,
) {
  return StoryListNotifier();
});

// 컴포넌트 사용
class StoryGrid extends ConsumerWidget {
  const StoryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storyListProvider);
    
    return stories.when(
      data: (stories) => GridView.builder(
        itemCount: stories.length,
        itemBuilder: (context, index) => StoryCard(story: stories[index]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
```

## 반응형 디자인

### 브레이크포인트
- **모바일**: < 600px
- **태블릿**: 600px - 1200px
- **데스크톱**: > 1200px

### 적응형 컴포넌트
```dart
class AdaptiveStoryCard extends ConsumerWidget {
  const AdaptiveStoryCard({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileCard();
        } else if (constraints.maxWidth < 1200) {
          return _buildTabletCard();
        } else {
          return _buildDesktopCard();
        }
      },
    );
  }
}
```

## 애니메이션 전략

### 진입 애니메이션
- 정적 콘텐츠용 페이드 인
- 목록용 슬라이드 업
- 인터랙티브 요소용 스케일

### 인터랙션 애니메이션
- 버튼 눌림 피드백
- 호버 상태 (데스크톱)
- 로딩 인디케이터

### 성능 고려사항
- 복잡한 애니메이션용 `AnimatedBuilder`
- 가능한 곳에서 `const` 생성자 사용
- 리페인트 경계 최적화

## 다음 단계
1. 아토믹 컴포넌트 먼저 생성
2. 분자 컴포넌트 구축
3. 유기체 컴포넌트 구현
4. 기존 화면 리팩토링
5. 애니메이션과 전환 추가
6. 다양한 화면 크기 테스트

---
*문서 생성일: 2026-03-05*
*프론트엔드 개발자: [Your Name]*
*컴포넌트 아키텍처: 아토믹 디자인 시스템*