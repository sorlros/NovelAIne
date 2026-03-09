import os
import json
import httpx
from typing import List, Dict, Any
from app.services.rag_service import RagService
from app.services.memory_service import MemoryService

class ChatService:
    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://novelaine.com",
            "X-Title": "NovelAIne",
        }
        self.model = os.getenv("LLM_MODEL", "tngtech/tng-r1t-chimera")
        
        self.rag_service = RagService()
        self.memory_service = MemoryService(max_buffer_size=10)

    async def generate_response(self, user_message: str, history: List[Dict[str, str]] = []) -> str:
        """
        RAG와 Memory가 결합된 최종 응답 생성 로직
        """
        # 1. RAG: 관련 기억 검색 (최적화: 키워드 감지 시에만 호출)
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(user_message)
        except Exception as e:
            print(f"RAG Error: {e}") 
            # RAG 실패해도 대화는 진행

        # 2. System Prompt 구성
        base_system_prompt = (
            "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 AI 스토리텔러입니다.\n"
            "사용자의 선택에 따라 흥미롭고 감정적인 이야기를 전개하세요.\n"
            "문체는 소설처럼 서술적이고 묘사가 풍부해야 합니다.\n"
        )
        
        if rag_context:
            base_system_prompt += f"\n[참고할 캐릭터/설정 정보]\n{rag_context}\n"
            
        # 3. Message 구성 (Memory 적용)
        # 현재 요청에 시스템 프롬프트가 없다면 추가
        current_messages = [{"role": "system", "content": base_system_prompt}]
        
        # 이전 기록 추가 (User가 보낸 history가 있다면)
        if history:
            current_messages.extend(self.memory_service.format_history(history))
            
        # 현재 사용자 메시지 추가
        current_messages.append({"role": "user", "content": user_message})

        # 4. LLM 호출 (Direct HTTP Request using httpx)
        data = {
            "model": self.model,
            "messages": current_messages,
            "temperature": 0.8,
            "max_tokens": 1000
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.base_url, 
                    headers=self.headers, 
                    json=data,
                    timeout=60.0
                )
                
                if response.status_code == 200:
                    resp_json = response.json()
                    return self._extract_response_text(resp_json)
                else:
                    error_msg = f"API Error {response.status_code}: {response.text}"
                    print(error_msg)
                    raise Exception(error_msg)
                    
        except Exception as e:
            print(f"LLM Generation Error: {e}")
            raise e

    async def start_new_story(
        self,
        genre: str,
        tone: str = None,
        protagonist_name: str = None,
        traits: List[str] = None,
        scenario: str = None
    ) -> Dict[str, Any]:
        """
        초기 설정을 바탕으로 소설의 제목, 개요, 첫 장면, 주인공 설정을 생성합니다.
        항상 JSON 형식으로 반환합니다.
        """
        system_prompt = (
            "You are a creative writer for an interactive novel app.\n"
            "Generate the story metadata in valid JSON format ONLY.\n"
            "Do not include any prose outside the JSON object.\n"
            "The keys must be: 'title', 'description', 'first_scene', 'protagonist_bio'."
        )

        user_prompt = f"""
        Create a new story with these settings:
        - Genre: {genre}
        - Tone: {tone or "Balanced"}
        - Protagonist Name: {protagonist_name or "Unknown"}
        - Traits: {", ".join(traits) if traits else "None"}
        - Opening Scenario: {scenario or "Standard beginning"}

        Response Format (JSON):
        {{
            "title": "Story Title",
            "description": "Short summary of the premise",
            "first_scene": "The actual narrative content of the first scene (approx 300 words). Engaging and immersive.",
            "protagonist_bio": "A short backstory for the character based on the traits and setting."
        }}
        """

        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.9,
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.base_url, 
                    headers=self.headers, 
                    json=data,
                    timeout=60.0
                )
                
                if response.status_code == 200:
                    resp_json = response.json()
                    content = self._extract_response_text(resp_json)
                    print(f"[DEBUG] LLM JSON Response: {content}")
                    return json.loads(content)
                else:
                    print(f"API Error {response.status_code}: {response.text}")
                    raise Exception(f"Failed to generate story: {response.status_code}")
                    
        except Exception as e:
            print(f"Story Generation Error: {e}")
            # Fallback for error handling
            return {
                "title": "새로운 모험",
                "description": "알 수 없는 이유로 생성에 실패했습니다.",
                "first_scene": f"당신은 눈을 떴습니다. 주변은 조용합니다. (오류: {e})",
                "protagonist_bio": "알 수 없음"
            }

    def _extract_response_text(self, response: dict) -> str:
        """Extract the actual message content from the API response"""
        if response and 'choices' in response and len(response['choices']) > 0:
            return response['choices'][0]['message']['content']
        return ""

    def _should_trigger_rag(self, message: str) -> bool:
        """
        RAG 호출 여부를 결정합니다.
        모든 대화에 RAG를 쓰면 느리고 비싸므로, '질문'이나 '명사'가 있을 때만 호출합니다.
        """
        # 1. 명백한 질문
        if "?" in message or "누구" in message or "어떤" in message or "왜" in message:
            return True
        
        # 2. 길이가 긴 문장 (복잡한 묘사나 지시일 가능성)
        if len(message) > 20:
            return True
            
        return False
