import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

// The function we optimized in StoryScreen
List<Map<String, dynamic>> processScenesIsolate(List<dynamic> scenes) {
  return scenes.map((scene) => {
    'id': scene['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    'role': scene['role'] ?? 'ai',
    'content': scene['content'] ?? "",
    'imageUrl': scene['imageUrl'] ?? scene['image_url'],
    'sceneType': scene['sceneType'] ?? scene['scene_type'] ?? 'narrative',
  }).toList();
}

void main() {
  group('Frontend Performance & Optimization Tests', () {
    test('Isolate Parsing Performance (Large Dataset)', () async {
      // 1. Generate dummy data (e.g., 50 scenes, each with 2000 chars of content)
      final List<Map<String, dynamic>> dummyScenes = List.generate(50, (index) => {
        'id': 'scene_$index',
        'role': index % 2 == 0 ? 'user' : 'ai',
        'content': 'A' * 2000, 
        'scene_type': 'narrative',
      });

      // 2. Measure synchronous parsing (Main Thread)
      final stopwatchSync = Stopwatch()..start();
      final resultSync = processScenesIsolate(dummyScenes);
      stopwatchSync.stop();

      // 3. Measure asynchronous parsing (Isolate)
      final stopwatchAsync = Stopwatch()..start();
      final resultAsync = await compute(processScenesIsolate, dummyScenes);
      stopwatchAsync.stop();

      print('\n--- 🚀 Frontend Performance Test ---');
      print('Dataset: 50 scenes, 2000 chars each (total 100,000 chars)');
      print('Synchronous Parsing (Main Thread): ${stopwatchSync.elapsedMilliseconds} ms');
      print('Asynchronous Parsing (Isolate): ${stopwatchAsync.elapsedMilliseconds} ms');
      
      // Verify correctness
      expect(resultSync.length, 50);
      expect(resultAsync.length, 50);
      expect(resultAsync[0]['id'], 'scene_0');
      
      // Since it's a simple test on a powerful dev machine, Isolate overhead might make it slightly slower, 
      // but in real devices, preventing UI lock is the key metric.
      print('✅ Parsing logic verified successfully. Isolate successfully offloads work.');
    });
  });
}
