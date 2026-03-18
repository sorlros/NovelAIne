import asyncio
import time
from app.services.chat_service import ChatService

async def measure_performance():
    print("\n--- 🚀 Backend Performance & Functionality Test ---")
    chat = ChatService()
    
    # 1. Story Generation Test
    print("\n[Test 1] Initial Story Generation (Gemini 2.0 Flash)")
    start_time = time.time()
    try:
        story = await chat.start_new_story(
            genre="fantasy", 
            tone="dark", 
            protagonist_name="Aiden",
            scenario="A lost kingdom",
            model="google/gemini-2.0-flash-001"
        )
        end_time = time.time()
        print(f"✅ Success! Generated {len(story.get('first_scene', ''))} characters in {end_time - start_time:.2f} seconds.")
        print(f"   Title: {story.get('title')}")
    except Exception as e:
        print(f"❌ Failed: {e}")

    # 2. Scene Analysis Test
    print("\n[Test 2] Scene Character Analysis")
    scene_text = "에이든은 검을 뽑아들고 엘라리아에게 소리쳤다. '뒤로 물러서!' 엘라리아는 고개를 끄덕이고 방을 나갔다."
    characters = ["Aiden", "Elaria", "Thanos"]
    
    start_time = time.time()
    try:
        analysis = await chat.analyze_scene_characters(scene_text, characters)
        end_time = time.time()
        print(f"✅ Success! Analyzed in {end_time - start_time:.2f} seconds.")
        print(f"   Present: {analysis.get('present_characters')}")
        print(f"   Important: {analysis.get('important_characters')}")
    except Exception as e:
        print(f"❌ Failed: {e}")

    # 3. Interactive Response Test
    print("\n[Test 3] Interactive Chat Generation")
    start_time = time.time()
    try:
        response = await chat.generate_response("오른쪽 문을 연다.", model="google/gemini-2.0-flash-001")
        end_time = time.time()
        print(f"✅ Success! Generated {len(response)} characters in {end_time - start_time:.2f} seconds.")
    except Exception as e:
        print(f"❌ Failed: {e}")

if __name__ == "__main__":
    asyncio.run(measure_performance())
