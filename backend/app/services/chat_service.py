import os
import json
import httpx
import re
import unicodedata
import random
import logging
import traceback
from typing import List, Dict, Any, Optional
from uuid import UUID
from app.services.rag_service import RagService
from app.services.memory_service import MemoryService

# Logger setup
logger = logging.getLogger(__name__)

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
            logger.error(f"Compression Error: {e}")
            return user_message

    async def generate_response(
        self, user_message: str, history: Optional[List[Dict[str, str]]] = None,
        model: str = None, narrative_type: str = "hero",
        story_id: UUID | str | None = None,
        user_id: UUID | str | None = None,
    ) -> str:
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(
                    user_message,
                    story_id=story_id,
                    user_id=user_id,
                )
        except Exception as e:
            logger.error(f"RAG Error: {e}")
            
        target_model = model or self.default_model
        compressed_message = await self._compress_to_english_keywords(user_message, model=target_model)

        if narrative_type == "ensemble":
            base_system_prompt = (
                "당신은 군상극(Ensemble Cast) 전문 소설가입니다. 특정 주인공 한 명에게 고정되지 않고, 세계 전체의 흐름과 다양한 인물들의 상호작용을 서술하세요.\n"
                "CRITICAL RULES:\n"
                "1. NO FIXED POV: 주어지는 지시사항을 '세계에 일어나는 사건'이나 '운명의 변화'로 해석하세요.\n"
                "2. MULTIPLE CHARACTERS: 현재 장면의 여러 인물들이 각자의 개성에 따라 반응하는 모습을 입체적으로 묘사하세요.\n"
                "3. WORLD BUILDING: 공간의 변화나 사회적 여파를 구체적인 감각 묘사로 전달하세요.\n"
                "4. FORMATTING: Separate every paragraph with TWO actual newline characters (\\n\\n).\n"
                "5. DIALOGUE: Every dialogue 「...」 MUST be placed on its own new line and separated from narration by double newlines.\n"
                "6. THE HOOK: 상황을 매듭짓지 말고, 세계의 변화가 인물들에게 어떤 선택을 강요하는지 보여주며 끝내세요.\n"
            )
        else:
            base_system_prompt = (
                "당신은 주인공 중심의 서사(Hero's Journey) 전문 소설가입니다. 철저히 주인공의 시점과 감정에 집중하여 서술하세요.\n"
                "CRITICAL RULES:\n"
                "1. FIXED POV: 사용자의 입력을 '주인공의 행동이나 의지'로 해석하세요.\n"
                "2. INNER THOUGHTS: 주인공의 심리 묘사와 감각 수용을 깊이 있게 다루세요.\n"
                "3. NPC INTERACTION: 주변 인물들은 주인공의 여정에 반응하는 조연으로 활용하세요.\n"
                "4. FORMATTING: Separate every paragraph with TWO actual newline characters (\\n\\n).\n"
                "5. DIALOGUE: Every dialogue 「...」 MUST be placed on its own new line and separated from narration by double newlines.\n"
                "6. THE HOOK: 주인공이 직면한 즉각적인 위기나 결단의 순간에서 멈추세요.\n"
            )
        
        if rag_context:
            if narrative_type == "ensemble":
                base_system_prompt += f"\n[World Lore & Relationships]\n이 정보는 세계관의 설정과 인물들 간의 복잡한 관계망입니다. 이를 활용해 장면의 사회적 맥락을 풍성하게 하세요.\n{rag_context}\n"
            else:
                base_system_prompt += f"\n[Protagonist Context]\n이 정보는 주인공의 과거, 능력, 혹은 현재 목표와 관련된 설정입니다. 주인공의 행동 이유를 정당화하는 데 사용하세요.\n{rag_context}\n"
            
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
                raise Exception(f"API Error {response.status_code}: {response.text}")
        except Exception as e:
            logger.error(f"LLM Generation Error: {e}")
            raise e

    async def start_new_story(
        self, genre: str, tone: str = None, protagonist_name: str = None,
        traits: List[str] = None, scenario: str = None, language: str = "en_US",
        model: str = None, narrative_type: str = "hero" # 추가
    ) -> Dict[str, Any]:
        target_model = model or self.default_model
        
        # [다양성 강화] 시나리오가 없는 경우(빠른 시작) 무작위 시드 주입
        if not scenario:
            random_seed = random.choice(self.theme_seeds)
            scenario = f"Include this secret theme element: {random_seed}"

        is_ensemble = narrative_type == "ensemble"

        if is_ensemble:
            system_prompt = (
                "You are a bestselling professional novelist specializing in ensemble cast narratives (군상극).\n"
                "In this mode, there is NO SINGLE main hero. The story focuses on the world and a group of diverse characters.\n"
                "Generate story metadata in strict JSON format.\n"
                "TITLE RULES:\n"
                "1. Be UNIQUE and evocative. Focus on the collective fate or the setting.\n"
                "2. Metaphorical language is preferred.\n"
                "CRITICAL RULES for 'first_scene': \n"
                "1. Perspective: Use a multi-POV or objective 3rd person perspective.\n"
                "2. Content: Introduce the atmosphere of the world and at least 2-3 distinct characters interacting.\n"
                "3. Length: Approx 3500 characters. Detailed sensory descriptions.\n"
                "4. Formatting: Use double newlines for paragraphs. Dialogues 「...」 on their own lines.\n"
                f"User Locale: {language}. Write all content in this language."
            )
            
            user_prompt = f"""
            Create a new immersive ENSEMBLE story (군상극):
            Genre: {genre}
            Tone: {tone}
            Setting/Scenario: {scenario}
            
            REQUIRED JSON FORMAT:
            {{
                "title": "Evocative title for the ensemble",
                "description": "Summary of the group dynamics and the world's crisis",
                "first_scene": "Detailed narrative introducing multiple POVs and the world.",
                "protagonist_name": "없음 (군상극)",
                "protagonist_bio": "이 서사는 특정 개인의 이야기가 아닌, {genre} 세계관과 그 속의 다양한 군상들의 연대기입니다.",
                "protagonist_traits": ["군상극", "다양한 시점", "세계관 중심"]
            }}
            """
        else:
            system_prompt = (
                "You are a bestselling professional novelist known for character-driven heroic epics.\n"
                "Generate story metadata in strict JSON format.\n"
                "TITLE RULES:\n"
                "1. Be UNIQUE and focus on the protagonist's journey.\n"
                "CRITICAL RULES for 'first_scene': \n"
                "1. Perspective: Tight 1st or 3rd person POV focused on the hero.\n"
                "2. Length: Approx 3500 characters.\n"
                "3. Formatting: Use double newlines for paragraphs. Dialogues 「...」 on their own lines.\n"
                f"User Locale: {language}. Write all content in this language."
            )

            user_prompt = f"""
            Create a new character-driven story:
            Genre: {genre}
            Tone: {tone}
            Hero: {protagonist_name}
            Traits: {traits}
            Scenario: {scenario}
            
            REQUIRED JSON FORMAT:
            {{
                "title": "Highly creative title focused on the hero",
                "description": "Short summary of the hero's unique struggle",
                "first_scene": "Detailed narrative introducing the hero's first action.",
                "protagonist_name": "Hero's name",
                "protagonist_bio": "Detailed background and personality",
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
                        logger.info("Standard JSON parse failed. Starting advanced key-value extraction (REPAIR mode)...")
                        
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
            logger.exception(f"Critical Story Generation Error: {str(e)}")
            raise e

    async def stream_generate_response(
        self, user_message: str, history: Optional[List[Dict[str, str]]] = None,
        model: str = None, narrative_type: str = "hero",
        story_id: UUID | str | None = None,
        user_id: UUID | str | None = None,
    ):
        """
        AI 응답을 한 글자(토큰)씩 실시간으로 전송하는 제너레이터
        """
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(
                    user_message,
                    story_id=story_id,
                    user_id=user_id,
                )
        except Exception as e:
            logger.warning(f"RAG search failed: {e}")
            
        target_model = model or self.default_model
        compressed_message = await self._compress_to_english_keywords(user_message, model=target_model)

        if narrative_type == "ensemble":
            base_system_prompt = (
                "당신은 군상극(Ensemble Cast) 전문 소설가입니다. 특정 주인공 한 명에게 고정되지 않고, 세계 전체의 흐름과 다양한 인물들의 상호작용을 서술하세요.\n"
                "CRITICAL RULES:\n"
                "1. NO FIXED POV: 주어지는 지시사항을 '세계에 일어나는 사건'이나 '운명의 변화'로 해석하세요.\n"
                "2. MULTIPLE CHARACTERS: 현재 장면의 여러 인물들이 각자의 개성에 따라 반응하는 모습을 입체적으로 묘사하세요.\n"
                "3. WORLD BUILDING: 공간의 변화나 사회적 여파를 구체적인 감각 묘사로 전달하세요.\n"
                "4. FORMATTING: Separate paragraphs with a double newline (\\n\\n).\n"
                "5. DIALOGUE: Use 「 」 for character dialogues. ALWAYS place each dialogue on a new line with double newlines before and after.\n"
                "6. THE HOOK: 상황을 매듭짓지 말고, 세계의 변화가 인물들에게 어떤 선택을 강요하는지 보여주며 끝내세요.\n"
            )
        else:
            base_system_prompt = (
                "당신은 주인공 중심의 서사(Hero's Journey) 전문 소설가입니다. 철저히 주인공의 시점과 감정에 집중하여 서술하세요.\n"
                "CRITICAL RULES:\n"
                "1. FIXED POV: 사용자의 입력을 '주인공의 행동이나 의지'로 해석하세요.\n"
                "2. INNER THOUGHTS: 주인공의 심리 묘사와 감각 수용을 깊이 있게 다루세요.\n"
                "3. NPC INTERACTION: 주변 인물들은 주인공의 여정에 반응하는 조연으로 활용하세요.\n"
                "4. FORMATTING: Separate paragraphs with a double newline (\\n\\n).\n"
                "5. DIALOGUE: Use 「 」 for character dialogues. ALWAYS place each dialogue on a new line with double newlines before and after.\n"
                "6. THE HOOK: 주인공이 직면한 즉각적인 위기나 결단의 순간에서 멈추세요.\n"
            )

        if rag_context:
            if narrative_type == "ensemble":
                base_system_prompt += f"\n[World Lore & Relationships]\n이 정보는 세계관의 설정과 인물들 간의 복잡한 관계망입니다. 이를 활용해 장면의 사회적 맥락을 풍성하게 하세요.\n{rag_context}\n"
            else:
                base_system_prompt += f"\n[Protagonist Context]\n이 정보는 주인공의 과거, 능력, 혹은 현재 목표와 관련된 설정입니다. 주인공의 행동 이유를 정당화하는 데 사용하세요.\n{rag_context}\n"
            
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
                        err_body = await response.aread()
                        logger.error(f"Streaming API Error {response.status_code}: {err_body.decode()}")
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
            logger.error(f"Streaming Exception: {e}")
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
                logger.error(f"Character Analysis API Error {response.status_code}: {response.text}")
                return {"present_characters": [], "important_characters": []}
        except Exception as e:
            logger.error(f"Character Analysis Exception: {e}")
            return {"present_characters": [], "important_characters": []}

    def _should_trigger_rag(self, message: str) -> bool:
        return "?" in message or len(message) > 20
