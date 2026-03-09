---
title: "[1인 개발기] LLM 토큰 최적화와 FastAPI 에러 슈팅 (422, 500)"
tags: ["FastAPI", "Flutter", "LLM", "Prompt Engineering", "Supabase", "Troubleshooting"]
---

## 🚀 NovelAIne 개발 일지

최근 1인 기획/개발로 진행 중인 **단편 AI 인터랙티브 소설 및 이미지 생성 플랫폼 'NovelAIne'**의 프론트엔드 UI/UX 안정화와 강력한 서사 엔진(LLM) 최적화를 진행하면서 겪은 문제들과 해결 과정을 Velog에 공유합니다.

---

## 1. 프론트엔드와 백엔드의 엇갈림: 422 Unprocessable Entity 🐛

스토리 생성 초기 진입점(`POST /api/stories`)에서 뜬금없이 `422 Unprocessable Entity` 에러가 발생했습니다.

### 원인 파악
- **Frontend (Flutter)**: 모바일 앱에서는 UX를 위해 유저에게 장르 라벨을 `"판타지 (Fantasy)"`, `"SF (Sci-Fi)"` 와 같이 직관적인 한글이 포함된 문자열로 보여주고, 이 값을 그대로 백엔드로 쐈습니다.
- **Backend (FastAPI)**: 반면 Pydantic 모델의 `genre` 필드는 `^(fantasy|scifi|mystery...)$` 등 정밀한 정규표현식(Regex)을 사용해 영어 소문자 고정값만 허용하도록 견고하게 락이 걸려 있었습니다. 페이로드의 형태 자체가 모델 검증을 통과하지 못한 것이죠.

### 해결 로직
백엔드의 스펙을 느슨하게 푸는 것(보안/구조적 위험 ❌) 대신, **프론트엔드 쪽에서 통신 직전에 안전하게 Mapper를 거치도록** 설계했습니다.

```dart
// ApiService.dart 내부의 헬퍼 함수
String _mapGenreToBackend(String? label) {
  if (label == null) return "fantasy";
  if (label.contains('Fantasy')) return "fantasy";
  if (label.contains('Sci-Fi')) return "scifi";
  // ... 생략
  return "other";
}
```
Payload 생성 시 `_mapGenreToBackend`를 한 번 태워서 백엔드가 원하는 순수 영문 문자열로 넘겨주자 `200 OK`와 응답이 깔끔하게 떨어졌습니다. 데이터 스키마의 무결성을 프론트 단에서 한 번 래핑하여 맞춰주는 근본적인 해결이었습니다.

---

## 2. 뼈아픈 DB 설계: 500 Internal Server Error (users_id_fkey) 🔥

오류 하나를 잡았더니 이번엔 `500 Server Error`가 반환되었습니다. 로그 확인 결과:
> `insert or update on table "public.stories" violates foreign key constraint "users_id_fkey"`

### 원인파악
NovelAIne은 "빠른 시작(Guest)" 회원가입 없이도 체험할 수 있도록 MVP를 구성 중이었습니다. 
백엔드 로직에서는 유저가 없을 경우 `uuid4`로 난수를 생성해 `public.users` 행을 억지로 만들어 스토리를 할당하려 했습니다.
하지만 Supabase 환경에서 저의 `public.users.id`는 철저히 **`auth.users.id` (실제 가입된 회원의 인증 테이블)** 를 바라보는 Foreign Key로 묶여있었습니다. 즉, DB 차원에서 "가입도 안된 가짜 UUID 따위는 저장해 줄 수 없다" 라며 블로킹을 건 것입니다.

### 나의 고찰 및 해결
DB의 근본적인 무결성(Integrity)이 제대로 작동하고 있다는 증거이기도 해서 내심 기뻤습니다. 이를 우회하기 위해 DB 제약조건을 박살 내는 대신, 파이썬 스크립트를 통해 Supabase Auth API로 정식 동작하는 데모 게스트 계정(`novelaineguest@gmail.com`)을 하나 주입 발급시켜, 비회원 플로우일 때는 이 계정의 ID를 사용해 스토리가 저장되도록 파이프라인 우회로를 정상적으로 개통했습니다.

---

## 3. 💸 LLM 토큰 압축 마법: 한국어를 던지면 영어 명사로 변환한다

한국어로된 소설 지시문은 영어 대비 LLM 토큰을 2~3배나 더 잡아먹습니다. 게다가 이전 문맥(`history`)이 계속 쌓이는 Interactive Novel 특성 상, 턴이 길어질수록 막대한 토큰 낭비와 속도 저하가 발생합니다.

이 구조적인 비용 한계를 타파하기 위해 **Two-Step 연쇄 LLM 프롬프트 압축 기법**을 도입했습니다.

### 💡 혁신적인 압축 메커니즘 (`_compress_to_english_keywords`)

1. 사용자가 챗 UI에서 `"마을 이장이 숨겨놓은 지하실 비밀을 파헤치고 주인공이 분노하는 씬을 써줘"` 라고 길게 입력합니다.
2. 메인 모델로 직행하는 대신, 빠르고 저렴한 모델 모드로 이 입력을 넘겨 **영어 키워드로만 탈색(압축)** 시킵니다. 
   - ➡️ 결과: `"village chief, hidden basement secret, protagonist angry, uncover"`
3. 매우 가벼워진 이 키워드 뭉치만 Context History 배열에 누적됩니다.
4. 메인 모델(예: Llama-3-70b)의 System Prompt에 강력한 지시를 넣습니다: 
   > *"The user will provide story directions as English keywords to save tokens. Based on these keywords, write the next scene strictly in KOREAN."*

결과적으로 **Context 길이와 토큰 유지 비용은 파격적으로 줄이면서도**, 반환되는 소설 퀄리티는 동일하게 한국어로 미려하게 뽑아내는 고성능 파이프라인 최적화에 성공했습니다! 😆

---

## 4. 모바일 화면 오버플로우(Bottom Overflowed) 소탕 작전 📱

백엔드를 정리한 후, 모바일 화면에서의 렌더링 에러(`Bottom Overflowed`) 현상들도 일망타진했습니다.

- **`AuthScreen` & `HomeScreen`**: `SizedBox`의 고정 높이 수치를 제거하고, 기기 사이즈에 맞게 유동적으로 늘어나는 `Expanded`를 적극 차용.
- **`ProfileScreen`**: 스크롤이 안되어 밑단이 짤리던 프로필 UI는 `NestedScrollView`를 통째로 이식해 헤더가 위로 말려 올라가는 세련된 뷰로 리팩토링.
- **`Creation Wizard`**: 키보드가 올라올 때 화면이 짓눌리는 현상은 `SafeArea` + `resizeToAvoidBottomInset: true` 그리고 `ListView`의 환상적인 조합으로 유격 없이 스크롤 되도록 완벽 방어!

---

오늘의 개발을 통해 프론트엔드와 백엔드를 오가며 데이터 모델 검증, DB 제약 조건 해결, 프롬프트 엔지니어링까지 풀스택의 재미를 전부 느낄 수 있었습니다. 앞으로도 계속 발전해나갈 NovelAIne를 기대해주세요! 🚀
