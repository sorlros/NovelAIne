import os
import json
import httpx
import re
import unicodedata
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
        self.model = os.getenv("LLM_MODEL", "google/gemini-2.0-flash-001")
        
        self.rag_service = RagService()
        self.memory_service = MemoryService(max_buffer_size=10)

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

    async def _compress_to_english_keywords(self, user_message: str) -> str:
        system_prompt = (
            "You are a summarization AI. Extract only the crucial actions, objects, and emotions "
            "from the user's input. Translate them into concise English keywords separated by commas."
        )
        
        data = {
            "model": self.model,
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

    async def generate_response(self, user_message: str, history: List[Dict[str, str]] = []) -> str:
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(user_message)
        except Exception as e:
            print(f"RAG Error: {e}")
            
        compressed_message = await self._compress_to_english_keywords(user_message)

        base_system_prompt = (
            "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 베스트셀러 소설 작가입니다.\n"
            "CRITICAL RULES:\n"
            "1. MUST use rich, literary prose with sensory details. WRITE A LONG, DETAILED SCENE.\n"
            "2. MUST include realistic dialogues using double quotes (\"\").\n"
            "3. FORMATTING: You MUST separate every paragraph with TWO actual newline characters (\\n\\n).\n"
            "4. LENGTH: Each response should be long enough to feel like a full chapter page (approx 800-1000 characters).\n"
        )
        
        if rag_context:
            base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"
            
        current_messages = [{"role": "system", "content": base_system_prompt}]
        if history:
            current_messages.extend(self.memory_service.format_history(history))
        current_messages.append({"role": "user", "content": f"[Directions]: {compressed_message}"})

        data = {
            "model": self.model,
            "messages": current_messages,
            "temperature": 0.8,
            "max_tokens": 2000 # Increased from 1000
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(self.base_url, headers=self.headers, json=data, timeout=60.0)
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
        traits: List[str] = None, scenario: str = None, language: str = "en_US"
    ) -> Dict[str, Any]:
        system_prompt = (
            "You are a bestselling professional novelist. Generate story metadata in strict JSON format.\n"
            "IMPORTANT: \n"
            "1. The 'first_scene' MUST be long and descriptive (at least 2000 characters).\n"
            "2. COMPLETION: You MUST end the 'first_scene' with a complete sentence ending in a period (.), exclamation (!), or question mark (?). NEVER end mid-sentence.\n"
            "3. Use '\\n\\n' for paragraphs.\n"
            "4. CRITICAL: Use '「' and '」' for character dialogues. DO NOT use double quotes (\") inside the story text.\n"
            f"User Locale: {language}. Write all content in this language."
        )

        user_prompt = f"""
        Create a new immersive story with these settings:
        Genre: {genre}, Tone: {tone}, Hero: {protagonist_name}, Traits: {traits}, Scenario: {scenario}
        
        REQUIRED JSON FORMAT:
        {{
            "title": "Story Title",
            "description": "Short summary",
            "first_scene": "Extremely long narrative (2000+ chars) using 「dialogue」. Ensure the last sentence is FULLY COMPLETED.",
            "protagonist_bio": "Character background"
        }}
        """

        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.8,
            "max_tokens": 8000,
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
                        print("[REPAIR] Standard parse failed. Starting advanced slicing...")
                        
                        keys = ["title", "description", "first_scene", "protagonist_bio"]
                        extracted = {}
                        
                        for i in range(len(keys)):
                            k_p = f'"{keys[i]}"'
                            start_p = content.find(k_p)
                            if start_p == -1:
                                extracted[keys[i]] = ""
                                continue
                            
                            val_start = content.find(':', start_p)
                            val_start = content.find('"', val_start) + 1
                            
                            if i < len(keys) - 1:
                                next_k = f'"{keys[i+1]}"'
                                val_end = content.find(next_k, val_start)
                                if val_end != -1:
                                    last_q = content.rfind('"', val_start, val_end)
                                    while last_q != -1:
                                        after_q = content[last_q+1:val_end].strip()
                                        if after_q == "," or after_q == "":
                                            val_end = last_q
                                            break
                                        last_q = content.rfind('"', val_start, last_q - 1)
                            else:
                                val_end = content.rfind('"', val_start, content.rfind('}'))

                            if val_end == -1 or val_end <= val_start: val_end = len(content)
                            extracted[keys[i]] = content[val_start:val_end].replace('\\n', '\n').replace('\\"', '"').strip()
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
                    raise Exception(f"API Error {response.status_code}")
        except Exception as e:
            print(f"Critical Generation Error: {e}")
            raise e

    async def stream_generate_response(self, user_message: str, history: List[Dict[str, str]] = []):
        """
        AI 응답을 한 글자(토큰)씩 실시간으로 전송하는 제너레이터
        """
        rag_context = ""
        try:
            if self._should_trigger_rag(user_message):
                rag_context = await self.rag_service.search_relevant_context(user_message)
        except: pass
            
        compressed_message = await self._compress_to_english_keywords(user_message)

        base_system_prompt = (
            "당신은 몰입형 인터랙티브 스토리텔링 플랫폼 'NovelAIne'의 베스트셀러 소설 작가입니다.\n"
            "CRITICAL RULES:\n"
            "1. MUST use rich, literary prose with sensory details.\n"
            "2. MUST include realistic dialogues using double quotes (\"\").\n"
            "3. FORMATTING: Separate paragraphs with a double newline (\\n\\n).\n"
        )
        if rag_context:
            base_system_prompt += f"\n[Story Lore/Context]\n{rag_context}\n"
            
        current_messages = [{"role": "system", "content": base_system_prompt}]
        if history:
            current_messages.extend(self.memory_service.format_history(history))
        current_messages.append({"role": "user", "content": f"[Directions]: {compressed_message}"})

        data = {
            "model": self.model,
            "messages": current_messages,
            "temperature": 0.8,
            "stream": True # 스트리밍 활성화
        }
        
        try:
            async with httpx.AsyncClient() as client:
                async with client.stream("POST", self.base_url, headers=self.headers, json=data, timeout=60.0) as response:
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

    def _should_trigger_rag(self, message: str) -> bool:
        return "?" in message or len(message) > 20
