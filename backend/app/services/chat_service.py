import os
import json
import httpx
import re
import unicodedata
import random
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
        # 기본 모델 설정 (기본값: Gemini 2.0 Flash)
        self.default_model = "google/gemini-2.0-flash-001"
        
        self.rag_service = RagService()
        self.memory_service = MemoryService(max_buffer_size=10)

        # 무작위 테마 시드 리스트 (빠른 시작의 다양성 확보용)
        self.theme_seeds = [
            "잊혀진 고대 유물", "몰락한 제국의 마지막 후계자", "심해의 부유하는 도시", 
            "기계 장치의 심장을 가진 안드로이드", "별의 파편을 수집하는 여행자", "그림자 속에 숨은 비밀 결사",
            "차원 균열 너머에서 온 방문자", "시간을 되돌리는 시계공", "하늘을 떠다니는 군도",
            "사라진 기억을 찾는 탐정", "마법과 증기 기관이 공존하는 시대", "꿈 속을 여행하는 유랑단",
            "금지된 금서를 지키는 사서", "영혼을 울리는 선율의 악기", "숲의 정령과 계약한 사냥꾼"
        ]

    def _deep_clean_string(self, text: str) -> str:
        """
        Removes or escapes characters that break JSON parsing.
        """
        if not text:
            return ""
        
        # 1. Remove non-printable control characters (except common ones like \n, \t)
        text = "".join(ch for ch in text if unicodedata.category(ch)[0] != "C" or ch in "\n\r\t")
        
        # 2. Convert actual raw newlines into the string "\n" to be JSON safe
        # This is the most common cause of "Unterminated string"
        text = text.replace("\r\n", "\\n").replace("\r", "\\n").replace("\n", "\\n")
        
        return text

    def _sanitize_dict(self, data: Any) -> Any:
        """
        Recursively cleans all strings in a dictionary or list.
        """
        if isinstance(data, dict):
            return {k: self._sanitize_dict(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._sanitize_dict(i) for i in data]
        elif isinstance(data, str):
            # We don't use _deep_clean_string here because json.loads already handles \n if they are escaped.
            # But we ensure no weird control characters remain.
            return "".join(ch for ch in data if unicodedata.category(ch)[0] != "C" or ch in "\n\r\t")
        return data

    async def _compress_to_english_keywords(self, user_message: str, model: str = None) -> str:
        system_prompt = (
            "You are a summarization AI. Extract only the crucial actions, objects, and emotions "
            "from the user's input. Translate them into concise English keywords separated by commas."
        )

        data = {
            "model": model or self.default_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message}
            ],
            "temperature": 0.3,
            "max_tokens": 100
        }

        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.base_url, headers=self.headers, json=data, timeout=30.0)
                if response.status_code == 200:
                    compressed = self._extract_response_text(response.json())
                    return compressed
                return user_message
        except Exception as e:
            print(f"Compression Error: {e}")
            return user_message

    async def generate_response(self, user_message: str, history: List[Dict[str, str]] = [], model: str = None) -> str:
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(user_message)
        except Exception as e:
            print(f"RAG Error: {e}")
            
        target_model = model or self.default_model
        compressed_message = await self._compress_to_english_keywords(user_message, model=target_model)

        base_system_prompt = (
            "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 베스트셀러 소설 작가입니다.\n"
            "CRITICAL RULES:\n"
            "1. MUST use rich, literary prose with sensory details.\n"
            "2. MUST include realistic dialogues using double quotes (\"\").\n"
            "3. FORMATTING: Separate every paragraph with TWO actual newline characters (\\n\\n).\n"
            "4. DIALOGUE READABILITY: Every dialogue 「...」 MUST be placed on its own new line and separated from narration by double newlines (\\n\\n) before and after. NEVER mix dialogue and narration in the same paragraph.\n"
            "5. INTERACTIVE LENGTH: Write about 3 to 5 paragraphs (approx 500-800 characters). Describe the direct consequence of the user's action with deep immersion.\n"
            "6. THE HOOK: NEVER resolve the entire situation. Always end the response at a cliffhanger, a new challenge, a character's question, or a turning point that FORCES the user to decide what to do next.\n"
        )
        
        if rag_context:
            base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"
            
        current_messages = [{"role": "system", "content": base_system_prompt}]
        if history:
            current_messages.extend(self.memory_service.format_history(history))
        current_messages.append({"role": "user", "content": f"[Directions]: {compressed_message}"})

        data = {
            "model": target_model,
            "messages": current_messages,
            "temperature": 0.8,
            "max_tokens": 1500 # Adjusted for optimal interactive length
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.base_url, headers=self.headers, json=data, timeout=90.0)
                if response.status_code == 200:
                    text = self._extract_response_text(response.json())
                    # Only remove dangerous control characters, keep newlines
                    return "".join(ch for ch in text if unicodedata.category(ch)[0] != "C" or ch in "\n\r\t")
                raise Exception(f"API Error {response.status_code}")
        except Exception as e:
            print(f"LLM Error: {e}")
            raise e

    async def start_new_story(
        self, genre: str, tone: str = None, protagonist_name: str = None,
        traits: List[str] = None, scenario: str = None, language: str = "en_US",
        model: str = None
    ) -> Dict[str, Any]:
        target_model = model or self.default_model
        
        # [다양성 강화] 시나리오가 없는 경우(빠른 시작) 무작위 시드 주입
        if not scenario:
            random_seed = random.choice(self.theme_seeds)
            scenario = f"Include this secret theme element: {random_seed}"

        system_prompt = (
            "You are a bestselling professional novelist known for creative and evocative storytelling.\n"
            "Generate story metadata in strict JSON format.\n"
            "TITLE RULES:\n"
            "1. Be UNIQUE and CREATIVE. Avoid generic titles like 'The Fantasy Adventure' or 'Shadow of Mystery'.\n"
            "2. Incorporate specific elements from the provided 'Scenario' and 'Traits' to make the title distinct.\n"
            "3. Use metaphorical or symbolic language that fits the 'Tone'.\n"
            "4. NEVER use the genre name directly in the title unless it is essential.\n"
            "5. Aim for a title that feels like a published novel (e.g., 'The Last Gear of London', 'Echoes from the Abyss').\n"
            "CRITICAL RULES for 'first_scene': \n"
            "1. LENGTH: The 'first_scene' should be around 3000-4000 characters. Detailed but stable for rendering.\n"
            "2. STRUCTURE: Write 8-10 detailed paragraphs.\n"
            "3. DETAIL: Use sensory descriptions and focus on world-building.\n"
            "4. COMPLETION: End with a complete sentence.\n"
            "5. DIALOGUE FORMATTING: Always place dialogues 「...」 on their own line, separated by double newlines (\\n\\n) from narration for readability. NEVER mix dialogue and narrative in the same paragraph.\n"
            "6. Use '\\n\\n' for paragraphs.\n"
            "7. DIALOGUE: Use '「' and '」'.\n"
            f"User Locale: {language}. Write all content in this language."
        )

        user_prompt = f"""
        Create a new immersive story with these unique settings:
        Genre: {genre}
        Tone: {tone}
        Hero: {protagonist_name}
        Traits: {traits}
        Scenario: {scenario}
        
        Task: Create a title that is specifically inspired by the scenario and traits, making it stand out even among other stories of the same genre.
        
        REQUIRED JSON FORMAT:
        {{
            "title": "A highly creative and specific title",
            "description": "Short summary that captures the unique twist of this story",
            "first_scene": "Detailed narrative (3500 characters) using 「dialogue」. Ensure the last sentence is FULLY COMPLETED.",
            "protagonist_name": "Suggested character name",
            "protagonist_bio": "Detailed character background and personality based on traits",
            "protagonist_traits": ["trait1", "trait2", "trait3"]
        }}
        """

        data = {
            "model": target_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.8,
            "max_tokens": 12000, 
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.base_url, headers=self.headers, json=data, timeout=120.0)
                if response.status_code == 200:
                    raw_text = self._extract_response_text(response.json())
                    
                    content = raw_text.strip()
                    start_idx = content.find('{')
                    end_idx = content.rfind('}')
                    if start_idx != -1 and end_idx != -1:
                        content = content[start_idx:end_idx + 1]
                    
                    try:
                        result = self._sanitize_dict(json.loads(content, strict=False))
                    except json.JSONDecodeError:
                        print("[REPAIR] Standard parse failed. Starting advanced key-value extraction...")
                        
                        keys = ["title", "description", "first_scene", "protagonist_name", "protagonist_bio", "protagonist_traits"]
                        extracted = {}
                        
                        for k in keys:
                            k_p = f'"{k}"'
                            start_p = content.find(k_p)
                            if start_p == -1:
                                extracted[k] = [] if "traits" in k else ""
                                continue
                            
                            val_start = content.find(':', start_p)
                            if val_start == -1:
                                extracted[k] = [] if "traits" in k else ""
                                continue

                            if "traits" in k:
                                list_start = content.find('[', val_start)
                                list_end = content.find(']', list_start)
                                if list_start != -1 and list_end != -1:
                                    try:
                                        extracted[k] = json.loads(content[list_start:list_end + 1])
                                    except Exception:
                                        extracted[k] = []
                                else:
                                    extracted[k] = []
                            else:
                                quote_start = content.find('"', val_start)
                                if quote_start != -1:
                                    # Find the matching closing quote, but be careful of escaped quotes
                                    curr = quote_start + 1
                                    while curr < len(content):
                                        quote_end = content.find('"', curr)
                                        if quote_end == -1:
                                            quote_end = len(content)
                                            break
                                        if content[quote_end - 1] != '\\':
                                            break
                                        curr = quote_end + 1
                                    
                                    val = content[quote_start + 1:quote_end]
                                    extracted[k] = val.replace('\\n', '\n').replace('\\"', '"').strip()
                                else:
                                    extracted[k] = ""
                        
                        result = self._sanitize_dict(extracted)

                    # --- [추가] 문장 완결성 후처리 로직 ---
                    if "first_scene" in result and result["first_scene"]:
                        fs = result["first_scene"].strip()
                        # 마지막 문장이 마침표나 대화 종료 기호로 끝나지 않았다면, 마지막 문장 제거 (불완전한 문장 제거)
                        last_punctuation = max(fs.rfind('.'), fs.rfind('!'), fs.rfind('?'), fs.rfind('」'))
                        if last_punctuation != -1 and last_punctuation < len(fs) - 1:
                            result["first_scene"] = fs[:last_punctuation + 1]
                    
                    return result
                else:
                    raise Exception(f"API Error {response.status_code}: {response.text}")
        except Exception as e:
            print(f"[CRITICAL] Generation Error: {str(e)}")
            traceback.print_exc()
            raise e

    async def stream_generate_response(self, user_message: str, history: List[Dict[str, str]] = [], model: str = None):
        """
        AI 응답을 한 글자(토큰)씩 실시간으로 전송하는 제너레이터
        """
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(user_message)
        except Exception as e:
            print(f"[WARNING] RAG search failed: {e}")
            
        target_model = model or self.default_model
        compressed_message = await self._compress_to_english_keywords(user_message, model=target_model)

        # 시스템 언어 감지 및 한국어 강제 지시
        base_system_prompt = (
            "당신은 베스트셀러 소설 작가입니다. 사용자의 입력을 바탕으로 다음 장면을 서술하세요.\n"
            "CRITICAL RULES:\n"
            "1. LANGUAGE: You MUST write in KOREAN. (한국어로 답변하세요)\n"
            "2. STYLE: Use rich, literary prose with sensory details.\n"
            "3. DIALOGUE: Use 「 」 for character dialogues. ALWAYS place each dialogue on a new paragraph with double newlines (\\n\\n) before and after.\n"
            "4. FORMATTING: Separate paragraphs with a double newline (\\n\\n).\n"
            "5. DIALOGUE READABILITY: NEVER mix dialogue and narration in the same paragraph for readability.\n"
            "6. INTERACTIVE LENGTH: Write about 3 to 5 paragraphs (approx 500-800 characters). Describe the direct consequence of the user's action with deep immersion.\n"
            "7. THE HOOK: NEVER resolve the entire situation. Always end the response at a cliffhanger, a new challenge, a character's question, or a turning point that FORCES the user to decide what to do next.\n"
        )
        if rag_context:
            base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"
            
        current_messages = [{"role": "system", "content": base_system_prompt}]
        if history:
            current_messages.extend(self.memory_service.format_history(history))
        current_messages.append({"role": "user", "content": f"[Directions]: {compressed_message}"})

        data = {
            "model": target_model,
            "messages": current_messages,
            "temperature": 0.8,
            "max_tokens": 1500, # Adjusted for optimal interactive length
            "stream": True 
        }
        
        try:
            async with httpx.AsyncClient() as client:
                async with client.stream("POST", self.base_url, headers=self.headers, json=data, timeout=120.0) as response:
                    if response.status_code != 200:
                        yield f"Error: {response.status_code}"
                        return

                    async for line in response.aiter_lines():
                        if not line or line.startswith(":"): continue
                        if line.startswith("data: "):
                            line = line[6:]
                        if line == "[DONE]": break
                        
                        try:
                            resp_json = json.loads(line)
                            if "choices" in resp_json and resp_json["choices"]:
                                delta = resp_json["choices"][0].get("delta", {})
                                if "content" in delta:
                                    yield delta["content"]
                        except:
                            continue
        except Exception as e:
            yield f"\n(연결 오류 발생: {str(e)})"

    def _extract_response_text(self, response: dict) -> str:
        if response and 'choices' in response and len(response['choices']) > 0:
            return response['choices'][0]['message']['content']
        return ""

    async def analyze_scene_characters(self, scene_content: str, all_characters: List[str], model: str = None) -> Dict[str, List[str]]:
        """
        Analyzes a scene to identify present and important characters.
        """
        if not all_characters:
            return {"present_characters": [], "important_characters": []}

        target_model = model or self.default_model

        system_prompt = (
            "You are a literary analyst for an interactive story platform.\n"
            "Analyze the given scene and the list of characters to determine who is physically present.\n"
            "RULES:\n"
            "1. A character is 'present' only if they are in the same physical space as the protagonist.\n"
            "2. If a character leaves, moves to another room, or says goodbye and exits, they are NO LONGER present.\n"
            "3. 'important_characters' are those who have a significant role in the current scene (talking, acting, or being the focus).\n"
            "4. Return strictly in JSON format."
        )
        
        user_prompt = f"Scene: {scene_content}\nCharacters to check: {', '.join(all_characters)}\n\n"
        user_prompt += "Output JSON format: {\"present_characters\": [], \"important_characters\": []}"

        data = {
            "model": target_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"}
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.base_url, headers=self.headers, json=data, timeout=30.0)
                if response.status_code == 200:
                    raw_text = self._extract_response_text(response.json())
                    return json.loads(raw_text)
                return {"present_characters": [], "important_characters": []}
        except Exception as e:
            print(f"Analysis Error: {e}")
            return {"present_characters": [], "important_characters": []}

    def _should_trigger_rag(self, message: str) -> bool:
        return "?" in message or len(message) > 20
