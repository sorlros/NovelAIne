class CreationPrompts {
  // 장르 (Genre)
  static const Map<String, String> genres = {
    '판타지 (Fantasy)': 'High Fantasy, magic, mythical creatures, medieval setting',
    'SF (Sci-Fi)': 'Science Fiction, futuristic technology, space travel, dystopia',
    '미스터리 (Mystery)': 'Mystery, detective, suspense, hidden clues, noir atmosphere',
    '로맨스 (Romance)': 'Romance, emotional connection, relationship drama, modern setting',
    '무협 (Wuxia)': 'Wuxia, martial arts, eastern philosophy, cultivation',
    '호러 (Horror)': 'Horror, psychological thriller, supernatural entities, dark atmosphere',
    '사이버펑크 (Cyberpunk)': 'Cyberpunk, high tech low life, neon lights, mega corporations',
    '아포칼립스 (Apocalypse)': 'Post-Apocalyptic, survival, ruined world, scarce resources',
  };

  // 분위기/톤 (Tone)
  static const Map<String, String> tones = {
    '가볍고 유쾌한 (Light)': 'Lighthearted, humorous, witty, fun adventure',
    '진지하고 무거운 (Serious)': 'Serious, dramatic, intense, philosophical',
    '감성적인 (Emotional)': 'Emotional, poetic, melancholic, character-driven',
    '박진감 넘치는 (Action)': 'Action-packed, fast-paced, grand scale, energetic',
    '어둡고 절망적인 (Dark)': 'Dark, gritty, hopeless, survivalist',
  };

  // 배경 설정 (World Setting - Optional Presets)
  static const Map<String, String> worldSettings = {
    '중세 왕국': 'A detailed medieval kingdom with knights and castles',
    '마법 학원': 'A prestigious academy for magic users',
    '우주 정거장': 'A busy space station on the edge of the galaxy',
    '네온 시티': 'A rain-slicked futuristic city controlled by corporations',
    '폐허가 된 서울': 'The ruins of Seoul overflown with vegetation after the fall',
  };

  // 주인공 성격 (Personality Traits)
  static const Map<String, String> personalityTraits = {
    '용감한': 'Brave',
    '냉철한': 'Cold/Logical',
    '다정한': 'Kind',
    '교활한': 'Cunning',
    '소심한': 'Timid',
    '낙천적인': 'Optimistic',
    '비관적인': 'Pessimistic',
    '호기심 많은': 'Curious',
  };
}
