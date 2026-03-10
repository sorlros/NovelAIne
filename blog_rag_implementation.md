# NovelAIne에서 RAG를 어떻게 활용했는가?

> **RAG(Retrieval-Augmented Generation)**는 LLM이 응답을 생성하기 전에, 관련된 외부 정보를 검색하여 프롬프트에 주입하는 기법입니다.
> NovelAIne에서는 RAG를 이용해 캐릭터 정보를 장기 기억처럼 LLM에 전달합니다.

---

## 1. 왜 RAG가 필요했나?

인터랙티브 소설 앱에서는 LLM이 **캐릭터의 외모, 성격, 배경**을 일관성 있게 기억해야 합니다.  
하지만 LLM은 대화가 길어질수록 초반 정보를 잊어버리고, 캐릭터를 다르게 묘사하는 문제가 생깁니다.

**해결책**: 매 응답 생성 시 Supabase에서 관련 캐릭터 정보를 벡터 유사도로 검색하고, 시스템 프롬프트에 주입합니다.

---

## 2. 전체 아키텍처

```
[사용자 입력]
      ↓
[_should_trigger_rag()] ── 조건 불충족 → 스킵
      ↓ (조건 충족)
[RagService.generate_embedding()]
   HuggingFace API → all-MiniLM-L6-v2 → 384차원 벡터 생성
      ↓
[RagService.search_relevant_context()]
   Supabase RPC → search_similar_characters()
   코사인 유사도 기반 Top-K 검색 (threshold=0.4, limit=3)
      ↓
[RAG 컨텍스트 → 시스템 프롬프트 주입]
      ↓
[LLM (Gemini 2.5 Flash via OpenRouter)] → 응답 생성
```

---

## 3. 핵심 코드 분석

### 3-1. 임베딩 생성 — `RagService.generate_embedding()`

```python
# backend/app/services/rag_service.py

from huggingface_hub import AsyncInferenceClient

class RagService:
    def __init__(self):
        self.client = AsyncInferenceClient(token=os.getenv("HF_TOKEN"))
        self.model_id = "sentence-transformers/all-MiniLM-L6-v2"

    async def generate_embedding(self, text: str) -> List[float]:
        """
        HuggingFace Feature Extraction API를 이용해 텍스트를 벡터로 변환합니다.
        all-MiniLM-L6-v2 모델 → 384차원 float 배열 반환
        """
        embedding = await self.client.feature_extraction(text, model=self.model_id)
        return [float(x) for x in embedding]
```

**포인트**:  
- 모델: `sentence-transformers/all-MiniLM-L6-v2` (경량, 영/한 모두 지원, 무료)  
- HuggingFace Inference API 무료 티어 사용 가능  
- 비동기(`async`) 처리로 응답 지연 최소화

---

### 3-2. 벡터 유사도 검색 — `search_relevant_context()`

```python
async def search_relevant_context(self, query: str, threshold: float = 0.4, limit: int = 3) -> str:
    # 1. 쿼리를 벡터로 변환
    embedding = await self.generate_embedding(query)

    # 2. Supabase pgvector RPC 호출
    response = self.supabase.rpc(
        "search_similar_characters",
        {
            "query_embedding": embedding,
            "match_threshold": threshold,  # 코사인 유사도 최솟값
            "match_count": limit           # 최대 반환 결과 수
        }
    ).execute()

    # 3. 결과를 자연어 컨텍스트로 포맷
    context_text = "\n[관련 캐릭터 기억]\n"
    for item in response.data:
        context_text += f"- {item['name']}: {item['description']}\n"

    return context_text
```

**포인트**:  
- Supabase의 `pgvector` 확장을 사용하여 벡터 유사도 검색 수행  
- `search_similar_characters`는 Supabase에 등록된 SQL 함수 (RPC)  
- 유사도가 `0.4` 미만인 결과는 제외하여 노이즈 방지

---

### 3-3. 조건부 RAG 트리거 — `_should_trigger_rag()`

```python
# backend/app/services/chat_service.py

def _should_trigger_rag(self, message: str) -> bool:
    """
    매 턴마다 RAG를 호출하면 느리고 API 비용이 발생합니다.
    질문 또는 긴 문장일 때만 RAG를 활성화합니다.
    """
    # 질문 감지
    if "?" in message or "누구" in message or "어떤" in message or "왜" in message:
        return True
    # 복잡한 묘사/지시 (20자 이상)
    if len(message) > 20:
        return True
    return False
```

**포인트**:  
- 단순 1~2단어 명령("달린다", "도망")에는 RAG를 스킵하여 응답 속도 향상  
- 캐릭터에 대한 질문이나 긴 서술에만 벡터 검색 실행  

---

### 3-4. RAG 컨텍스트 → 시스템 프롬프트 주입

```python
async def generate_response(self, user_message: str, history: List[Dict]) -> str:
    # 1. RAG 조건 확인 후 컨텍스트 검색
    rag_context = ""
    if self._should_trigger_rag(user_message):
        rag_context = await self.rag_service.search_relevant_context(user_message)

    # 2. 기본 시스템 프롬프트
    base_system_prompt = (
        "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 베스트셀러 소설 작가입니다.\n"
        ...
    )

    # 3. RAG 컨텍스트가 있으면 시스템 프롬프트에 추가
    if rag_context:
        base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"

    # 4. LLM 호출
    ...
```

**포인트**:  
- RAG 결과를 `[Story Lore/Context]` 섹션으로 시스템 프롬프트 하단에 추가  
- LLM이 이 정보를 "공식 설정"처럼 인식하도록 포맷 설계  
- RAG 실패 시에도 예외 처리 후 정상 대화 진행 (Graceful Degradation)

---

### 3-5. DB 스키마 — `Character` 모델의 embedding 필드

```python
# backend/app/schemas/models.py

class Character(CharacterBase):
    id: UUID
    user_id: UUID
    embedding: Optional[List[float]] = None  # Vector for RAG ← 핵심
    created_at: datetime
    updated_at: datetime
```

**포인트**:  
- Supabase `characters` 테이블에 `embedding vector(384)` 컬럼 존재  
- 캐릭터 생성 시 설명(description)을 임베딩하여 저장  
- `pgvector` 확장의 코사인 유사도 함수로 검색

---

## 4. 전체 흐름 요약

| 단계 | 역할 | 기술 |
|------|------|------|
| 캐릭터 생성 | 캐릭터 설명 → 벡터 변환 후 DB 저장 | HuggingFace API |
| 대화 중 | 사용자 입력이 RAG 조건 충족 여부 판단 | 키워드 휴리스틱 |
| 검색 | 입력 쿼리를 벡터화 후 유사 캐릭터 검색 | Supabase pgvector |
| 주입 | 검색 결과를 시스템 프롬프트에 추가 | Prompt Engineering |
| 생성 | 캐릭터 정보를 참조하여 일관된 소설 생성 | Gemini 2.5 Flash |

---

## 5. 개선 포인트 (향후 계획)

- **하이브리드 RAG**: 벡터 검색 + 키워드 검색(BM25)을 결합하여 정확도 향상
- **씬 단위 임베딩**: 캐릭터뿐 아니라 이전 씬 내용도 임베딩하여 플롯 일관성 강화
- **Re-ranking**: 검색된 결과를 LLM으로 재순위화하여 관련성 향상
- **캐싱**: 동일 쿼리 임베딩 재사용으로 HuggingFace API 호출 횟수 절감

---

## 6. 테스트 코드

```python
# backend/test_rag.py

async def main():
    rag = RagService()

    # 임베딩 생성 테스트
    text = "주인공의 성격은 냉철하다."
    vector = await rag.generate_embedding(text)
    print(f"Embedding length: {len(vector)}")   # → 384
    print(f"First 5 dims: {vector[:5]}")

    # 컨텍스트 검색 테스트
    context = await rag.search_relevant_context("주인공의 성격")
    print(f"Search Result:\n{context}")
```

실행:
```bash
cd backend
python test_rag.py
```

---

*NovelAIne — 2026.03*
