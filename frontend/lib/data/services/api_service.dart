import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/story_model.dart';
import '../models/creation_config.dart';

class ApiService {
  final String _baseUrl = AppConstants.baseUrl;

  // Auth API
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['error']);
      }
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String username,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['error']);
      }
    } else {
      throw Exception('Signup failed: ${response.body}');
    }
  }

  Future<void> logout() async {
    // For now, simple client side logout.
    // If you add token storage (SharedPreferences), clear it here.
    return;
  }

  // Chat API
  Future<Map<String, dynamic>> chat(String message) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'response': data['response'] as String,
        'bgmUrl': data['bgmUrl'] as String?,
      };
    } else {
      throw Exception('Failed to load chat response');
    }
  }

  // Streaming Chat API
  Stream<String> streamChat(String storyId, String message, {List<Map<String, String>>? history}) async* {
    final client = http.Client();
    final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'story_id': storyId,
      'message': message,
      'history': history ?? [],
    });

    // Custom request sending with longer timeout
    final response = await client.send(request).timeout(const Duration(seconds: 150));

    if (response.statusCode == 200) {
      // 바이트 스트림을 문자열 스트림으로 변환
      yield* response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter()); 
    } else {
      throw Exception('Streaming failed: ${response.statusCode}');
    }
  }

  // Generate Image API
  Future<String> generateImage(
    String messageId,
    String prompt,
    String sceneType, {
    String? storyId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/images/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message_id': messageId,
        'prompt': prompt,
        'scene_type': sceneType,
        if (storyId != null) 'story_id': storyId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['imageUrl'] != null) {
        return data['imageUrl'];
      } else {
        throw Exception('imageUrl not found in response');
      }
    } else {
      throw Exception('Failed to generate image: ${response.statusCode}');
    }
  }

  // Stories API
  Future<List<StoryModel>> fetchStories({String? userId}) async {
    final uri = userId != null 
        ? Uri.parse('$_baseUrl/stories?user_id=$userId')
        : Uri.parse('$_baseUrl/stories');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => StoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch stories: ${jsonResponse['error']}');
      }
    } else {
      throw Exception('Failed to connect to API');
    }
  }

  // Fetch Single Story (with characters)
  Future<Map<String, dynamic>> fetchStory(String storyId) async {
    final response = await http.get(Uri.parse('$_baseUrl/stories/$storyId'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return jsonResponse['data'];
      } else {
        throw Exception('Failed to fetch story: ${jsonResponse['error']}');
      }
    } else {
      throw Exception('Failed to load story: ${response.statusCode}');
    }
  }

  // Characters API
  Future<List<dynamic>> fetchCharacters({String? userId}) async {
    final uri = userId != null
        ? Uri.parse('$_baseUrl/characters?user_id=$userId')
        : Uri.parse('$_baseUrl/characters');
        
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return jsonResponse['data']; // Will map in provider
      } else {
        throw Exception('Failed to fetch characters: ${jsonResponse['error']}');
      }
    } else {
      throw Exception('Failed to load characters: ${response.statusCode}');
    }
  }

  // Create Character (Standalone)
  Future<Map<String, dynamic>> createCharacter(
    String name,
    String description,
    List<String> traits, {
    String? appearanceDescription,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/characters'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
        'personality_traits': traits,
        if (appearanceDescription != null)
          'appearance_description': appearanceDescription,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return jsonResponse['data'];
      } else {
        throw Exception("Failed to create character: ${jsonResponse['error']}");
      }
    } else {
      throw Exception('Failed to create character: ${response.body}');
    }
  }

  // Update Character API
  Future<Map<String, dynamic>> updateCharacter(
    String characterId,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/characters/$characterId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['error']);
      }
    } else {
      throw Exception('Failed to update character: ${response.statusCode}');
    }
  }

  // Upload Character Image
  Future<String> uploadCharacterImage(
    String characterId,
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    final uri = Uri.parse('$_baseUrl/characters/$characterId/upload-image');
    final request = http.MultipartRequest('POST', uri);
    
    // Using fromBytes to ensure Web compatibility
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: fileName ?? 'profile_image.jpg',
    );
    
    request.files.add(multipartFile);
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return jsonResponse['data']['image_url'] as String;
      }
    }
    throw Exception('Failed to upload image: ${response.body}');
  }

  // Update Story API
  Future<Map<String, dynamic>> updateStory(String storyId, Map<String, dynamic> updates) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/stories/$storyId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decoder.convert(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['error']);
      }
    } else {
      throw Exception('Failed to update story: ${response.statusCode}');
    }
  }

  // Analyze Scene API for characters
  Future<Map<String, dynamic>> analyzeScene(
    String storyId,
    String content,
    List<String> characterNames,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/stories/$storyId/scenes/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'character_names': characterNames,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['error']);
      }
    } else {
      throw Exception('Failed to analyze scene: ${response.statusCode}');
    }
  }

  // Helper to map UI labels to backend ENUM
  String _mapGenreToBackend(String? label) {
    if (label == null) return "fantasy";
    if (label.contains('Fantasy')) return "fantasy";
    if (label.contains('Sci-Fi')) return "scifi";
    if (label.contains('Mystery')) return "mystery";
    if (label.contains('Romance')) return "romance";
    if (label.contains('Wuxia')) return "wuxia";
    if (label.contains('Horror')) return "horror";
    if (label.contains('Cyberpunk')) return "cyberpunk";
    if (label.contains('Apocalypse')) return "apocalypse";
    return "other";
  }

  // Create Story (Wizard)
  Future<StoryModel> createStory(CreationConfig config, {String? userId}) async {
    final url = Uri.parse('$_baseUrl/stories');

    // Map Config to Backend Request
    final Map<String, dynamic> body = {
      "user_id": userId,
      "genre": _mapGenreToBackend(config.genreLabel),
      "tone": config.toneLabel,
      "protagonist_name": config.userName,
      "protagonist_traits": config.personalityTraits,
      if (config.appearanceDescription != null &&
          config.appearanceDescription!.isNotEmpty)
        "protagonist_appearance_description": config.appearanceDescription,
      // We don't have explicit scenario input in UI yet, but model supports it
      // "opening_scenario": ...
      "language": ui.PlatformDispatcher.instance.locale
          .toLanguageTag(), // e.g., 'ko-KR', 'en-US'
      "llm_model": config.llmModel ?? "google/gemini-2.0-flash-001",
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final String rawBody = utf8.decode(response.bodyBytes);
      try {
        final jsonResponse = jsonDecode(rawBody);
        if (jsonResponse['success'] == true) {
          return StoryModel.fromJson(jsonResponse['data']);
        } else {
          throw Exception('Failed to create story: ${jsonResponse['error']}');
        }
      } catch (e) {
        debugPrint('--- JSON Parsing Error Details ---');
        debugPrint('Error: $e');
        debugPrint('Raw Response Content: $rawBody');
        debugPrint('----------------------------------');
        // Let the exception bubble up to the UI so we can see the exact cause
        rethrow;
      }
    }
 else {
      throw Exception(
        'Failed to create story: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Delete Story API
  Future<bool> deleteStory(String storyId) async {
    final url = Uri.parse('$_baseUrl/stories/$storyId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Failed to delete story. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to delete story: $e');
    }
  }

  // Fetch Scenes for a Story
  Future<List<dynamic>> fetchScenes(String storyId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/stories/$storyId/scenes'),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return jsonResponse['data'];
      } else {
        throw Exception('Failed to fetch scenes: ${jsonResponse['error']}');
      }
    } else {
      throw Exception('Failed to load scenes: ${response.statusCode}');
    }
  }

  // Chat APIe Scene
  // This is a simplified version, in reality we might need full Story/Scene models
  Future<Map<String, dynamic>> createScene(
    String storyId,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/stories/$storyId/scenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'chapter_id': null, // Optional
        'sequence': 1, // Logic needed to increment this
        'scene_type': 'narrative',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['data'];
    } else {
      throw Exception('Failed to create scene: ${response.body}');
    }
  }
}
