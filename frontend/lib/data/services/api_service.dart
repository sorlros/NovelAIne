import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/story_model.dart';
import '../models/creation_config.dart'; // Added

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

  // Generate Image API
  Future<String> generateImage(
    String messageId,
    String prompt,
    String sceneType,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/images/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message_id': messageId,
        'prompt': prompt,
        'scene_type': sceneType,
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
  Future<List<StoryModel>> fetchStories() async {
    final response = await http.get(Uri.parse('$_baseUrl/stories'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => StoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch stories: ${jsonResponse['error']}');
      }
    } else {
      throw Exception('Failed to load stories: ${response.statusCode}');
    }
  }

  // Characters API
  Future<List<dynamic>> fetchCharacters() async {
    final response = await http.get(Uri.parse('$_baseUrl/characters'));

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
    List<String> traits,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/characters'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
        'personality_traits': traits,
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

  // Upload Character Image
  Future<String> uploadCharacterImage(
    String characterId,
    String imagePath,
  ) async {
    final uri = Uri.parse('$_baseUrl/characters/$characterId/upload-image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));
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

  // Update Story (Rename/Status)
  Future<void> updateStory(String storyId, Map<String, dynamic> updates) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/stories/$storyId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update story: ${response.body}');
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
  Future<StoryModel> createStory(CreationConfig config) async {
    final url = Uri.parse('$_baseUrl/stories');

    // Map Config to Backend Request
    final Map<String, dynamic> body = {
      "genre": _mapGenreToBackend(config.genreLabel),
      "tone": config.toneLabel,
      "protagonist_name": config.userName,
      "protagonist_traits": config.personalityTraits,
      // We don't have explicit scenario input in UI yet, but model supports it
      // "opening_scenario": ...
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return StoryModel.fromJson(jsonResponse['data']);
      } else {
        throw Exception('Failed to create story: ${jsonResponse['error']}');
      }
    } else {
      throw Exception(
        'Failed to create story: ${response.statusCode} - ${response.body}',
      );
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
