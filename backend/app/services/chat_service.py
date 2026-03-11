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
        # self.model = os.getenv("LLM_MODEL", "tngtech/deepseek-r1t2-chimera")
        self.model = os.getenv("LLM_MODEL", "google/gemini-2.5-flash")
        
        self.rag_service = RagService()
        self.memory_service = MemoryService(max_buffer_size=10)

    async def _compress_to_english_keywords(self, user_message: str) -> str:
        """
        Compresses the user's natural language input (Korean) into English keywords.
        Saves tokens by only sending essential actions/nouns to the main story generation.
        """
        system_prompt = (
            "You are a summarization AI. Extract only the crucial actions, objects, and emotions "
            "from the user's input. Translate them into concise English keywords separated by commas. "
            "Do not write full sentences. Example: '주인공이 검을 뽑아서 드래곤에게 달려간다' -> "
            "'protagonist draws sword, charges at dragon'"
        )
        
        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            "temperature": 0.3, # Low temperature for accurate extraction
            "max_tokens": 100
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.base_url, 
                    headers=self.headers, 
                    json=data,
                    timeout=30.0
                )
                
                if response.status_code == 200:
                    compressed = self._extract_response_text(response.json())
                    print(f"[DEBUG] Original input: {user_message}")
                    print(f"[DEBUG] Compressed to keywords: {compressed}")
                    return compressed
                else:
                    return user_message # Fallback to original if API fails
        except Exception as e:
            print(f"Compression Error: {e}")
            return user_message # Fallback

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
            
        # 2. Token Optimization: Compress User Input to English Keywords
        compressed_message = await self._compress_to_english_keywords(user_message)

        # 3. System Prompt 구성
        base_system_prompt = (
            "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 베스트셀러 소설 작가입니다.\n"
            "The user will provide story directions as English keywords to save tokens.\n"
            "Based on these keywords and the story context, write the next scene in KOREAN (or the user's preferred language).\n"
            "CRITICAL RULES:\n"
            "1. MUST use rich, literary prose with sensory details (Show, don't just Tell).\n"
            "2. MUST include realistic and engaging dialogues between characters using double quotes (\"\").\n"
            "3. DO NOT act like a chatbot or a game master. NEVER ask '무엇을 하시겠습니까?' (What do you want to do?). End the scene naturally like a paragraph in a novel.\n"
            "4. FORMATTING: You MUST separate every paragraph and every spoken dialogue with a double newline (`\\n\\n`). Do NOT output a single wall of text.\n"
        )
        
        if rag_context:
            base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"
            
        # 4. Message 구성 (Memory 적용)
        current_messages = [{"role": "system", "content": base_system_prompt}]
        
        if history:
            current_messages.extend(self.memory_service.format_history(history))
            
        current_messages.append({"role": "user", "content": f"[Directions]: {compressed_message}"})

        # 5. LLM 호출
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
        scenario: str = None,
        language: str = "en_US"
    ) -> Dict[str, Any]:
        """
        초기 설정을 바탕으로 소설의 제목, 개요, 첫 장면, 주인공 설정을 생성합니다.
        항상 JSON 형식으로 반환합니다.
        """
        system_prompt = (
            "You are a bestselling author for an interactive novel app.\n"
            "Generate the story metadata in valid JSON format ONLY.\n"
            "Do not include any prose outside the JSON object.\n"
            "The 'first_scene' MUST be written in a highly engaging, literary novel style, rich with sensory details and realistic character dialogues (\"\").\n"
            "The keys must be: 'title', 'description', 'first_scene', 'protagonist_bio'.\n"
            f"CRITICAL: The user's locale is '{language}'. You MUST translate all generated content (title, description, first_scene, protagonist_bio) into this language naturally.\n"
            "FORMATTING: You MUST separate every paragraph and every spoken dialogue with a double newline (`\\n\\n`) in the 'first_scene'."
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
            "first_scene": "The actual narrative content of the first scene (approx 300 words). MUST include immersive descriptions and character dialogue.",
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
            "max_tokens": 2000,
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
                    
                    content_str = content.strip()
                    if content_str.startswith("```json"):
                        content_str = content_str[7:]
                    elif content_str.startswith("```"):
                        content_str = content_str[3:]
                    if content_str.endswith("```"):
                        content_str = content_str[:-3]
                        
                    return json.loads(content_str.strip())
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
