import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../models/community_models.dart';
import '../models/story_model.dart';
import '../models/creation_config.dart';

class ApiService {
  final String _baseUrl = AppConstants.baseUrl;
  static String? _accessToken;
  static Future<String?> Function()? _accessTokenRefresher;
  static Future<String?>? _refreshFuture;

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static void setAccessTokenRefresher(Future<String?> Function()? refresher) {
    _accessTokenRefresher = refresher;
  }

  static void clearAccessToken() {
    _accessToken = null;
  }

  static Future<void> _ensureFreshAccessToken() async {
    final refresher = _accessTokenRefresher;
    if (refresher == null) {
      return;
    }
    _refreshFuture ??= refresher().whenComplete(() {
      _refreshFuture = null;
    });
    final token = await _refreshFuture;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
    }
  }

  Map<String, String> get _jsonHeaders {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  Map<String, String> get _authHeaders {
    return {if (_accessToken != null) 'Authorization': 'Bearer $_accessToken'};
  }

  // Auth API
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _jsonHeaders,
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
      headers: _jsonHeaders,
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

  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        return data['data'];
      }
      throw Exception(data['error']);
    }
    throw Exception('Session refresh failed: ${response.statusCode}');
  }

  Future<void> logout() async {
    try {
      await _ensureFreshAccessToken();
      await http
          .post(Uri.parse('$_baseUrl/auth/logout'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Server logout skipped: $e');
    }
  }

  // Chat API
  Future<Map<String, dynamic>> chat(
    String storyId,
    String message, {
    List<Map<String, String>>? history,
    String? clientRequestId,
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'story_id': storyId,
        'message': message,
        'history': history ?? [],
        if (clientRequestId != null) 'client_request_id': clientRequestId,
      }),
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
  Stream<String> streamChat(
    String storyId,
    String message, {
    List<Map<String, String>>? history,
    String? clientRequestId,
  }) async* {
    await _ensureFreshAccessToken();
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream'));
      request.headers.addAll(_jsonHeaders);
      request.body = jsonEncode({
        'story_id': storyId,
        'message': message,
        'history': history ?? [],
        if (clientRequestId != null) 'client_request_id': clientRequestId,
      });

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 150));

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          final markerIndex = chunk.indexOf('[STREAM_ERROR:');
          if (markerIndex != -1) {
            final markerEnd = chunk.indexOf(']', markerIndex);
            final message = markerEnd == -1
                ? '응답 생성 중 문제가 발생했습니다.'
                : chunk.substring(
                    markerIndex + '[STREAM_ERROR:'.length,
                    markerEnd,
                  );
            throw Exception(message);
          }
          yield chunk;
        }
      } else {
        throw Exception('Streaming failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  // Generate Image API
  Future<String> generateImage(
    String messageId,
    String prompt,
    String sceneType, {
    String? storyId,
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/images/generate'),
      headers: _jsonHeaders,
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
    await _ensureFreshAccessToken();
    final uri = userId != null
        ? Uri.parse('$_baseUrl/stories?user_id=$userId')
        : Uri.parse('$_baseUrl/stories');

    final response = await http.get(uri, headers: _authHeaders);

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

  Future<List<StoryModel>> fetchPublicStories({
    String? genre,
    int limit = 20,
    int offset = 0,
  }) async {
    await _ensureFreshAccessToken();
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (genre != null && genre.isNotEmpty) 'genre': genre,
    };
    final uri = Uri.parse(
      '$_baseUrl/stories/public',
    ).replace(queryParameters: query);

    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => StoryModel.fromJson(json)).toList();
      }
      throw Exception(
        'Failed to fetch public stories: ${jsonResponse['error']}',
      );
    }
    throw Exception('Failed to connect to public stories API');
  }

  Future<List<CommunityStoryModel>> fetchCommunityFeed({
    String? genre,
    int limit = 20,
    int offset = 0,
  }) async {
    await _ensureFreshAccessToken();
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (genre != null && genre.isNotEmpty) 'genre': genre,
    };
    final uri = Uri.parse(
      '$_baseUrl/community/feed',
    ).replace(queryParameters: query);

    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => CommunityStoryModel.fromJson(json)).toList();
      }
      throw Exception(
        'Failed to fetch community feed: ${jsonResponse['error']}',
      );
    }
    throw Exception('Failed to connect to community feed API');
  }

  Future<List<StoryCommentModel>> fetchStoryComments(String storyId) async {
    await _ensureFreshAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/community/stories/$storyId/comments'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        return data.map((json) => StoryCommentModel.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch comments: ${jsonResponse['error']}');
    }
    throw Exception('Failed to load comments: ${response.statusCode}');
  }

  Future<StoryCommentModel> addStoryComment(
    String storyId,
    String content,
  ) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/community/stories/$storyId/comments'),
      headers: _jsonHeaders,
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return StoryCommentModel.fromJson(jsonResponse['data']);
      }
      throw Exception('Failed to add comment: ${jsonResponse['error']}');
    }
    throw Exception('Failed to add comment: ${response.statusCode}');
  }

  Future<void> deleteStoryComment(String commentId) async {
    await _ensureFreshAccessToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/community/comments/$commentId'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) return;
      throw Exception('Failed to delete comment: ${jsonResponse['error']}');
    }
    throw Exception('Failed to delete comment: ${response.statusCode}');
  }

  Future<void> reportStoryComment(
    String commentId, {
    String reason = 'inappropriate',
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/community/comments/$commentId/report'),
      headers: _jsonHeaders,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) return;
      throw Exception('Failed to report comment: ${jsonResponse['error']}');
    }
    throw Exception('Failed to report comment: ${response.statusCode}');
  }

  Future<void> setStoryLike(String storyId, {required bool isLiked}) async {
    await _ensureFreshAccessToken();
    final uri = Uri.parse('$_baseUrl/community/stories/$storyId/like');
    final response = isLiked
        ? await http.post(uri, headers: _authHeaders)
        : await http.delete(uri, headers: _authHeaders);
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) return;
      throw Exception('Failed to update like: ${jsonResponse['error']}');
    }
    throw Exception('Failed to update like: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createMediaJob({
    required String storyId,
    required String sceneId,
    required String mediaType,
    String? prompt,
    String sceneType = 'event',
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/media/jobs'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'story_id': storyId,
        'scene_id': sceneId,
        'media_type': mediaType,
        'scene_type': sceneType,
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
      }),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
      throw Exception('Failed to create media job: ${jsonResponse['error']}');
    }
    throw Exception('Failed to create media job: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchMediaJob(String jobId) async {
    await _ensureFreshAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/media/jobs/$jobId'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['success'] == true) {
        return Map<String, dynamic>.from(jsonResponse['data']);
      }
      throw Exception('Failed to fetch media job: ${jsonResponse['error']}');
    }
    throw Exception('Failed to fetch media job: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> waitForMediaJob(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 2),
    int maxAttempts = 45,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final result = await fetchMediaJob(jobId);
      final job = Map<String, dynamic>.from(result['job']);
      final status = job['status'];
      if (status == 'succeeded') return result;
      if (status == 'failed') {
        throw Exception(job['error'] ?? 'Media generation failed');
      }
      await Future<void>.delayed(pollInterval);
    }
    throw Exception('Media generation timed out');
  }

  Future<Map<String, dynamic>> generateSceneBgm({
    required String storyId,
    required String sceneId,
    String? prompt,
  }) async {
    final created = await createMediaJob(
      storyId: storyId,
      sceneId: sceneId,
      mediaType: 'bgm',
      prompt: prompt,
    );
    final job = Map<String, dynamic>.from(created['job']);
    final completed = job['status'] == 'succeeded'
        ? created
        : await waitForMediaJob(job['id']);
    return Map<String, dynamic>.from(completed['scene']);
  }

  Future<Map<String, dynamic>> generateSceneImage({
    required String storyId,
    required String sceneId,
    required String prompt,
    String sceneType = 'event',
  }) async {
    final created = await createMediaJob(
      storyId: storyId,
      sceneId: sceneId,
      mediaType: 'image',
      prompt: prompt,
      sceneType: sceneType,
    );
    final job = Map<String, dynamic>.from(created['job']);
    final completed = job['status'] == 'succeeded'
        ? created
        : await waitForMediaJob(job['id']);
    return Map<String, dynamic>.from(completed['scene']);
  }

  // Fetch Single Story (with characters)
  Future<Map<String, dynamic>> fetchStory(String storyId) async {
    await _ensureFreshAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/stories/$storyId'),
      headers: _authHeaders,
    );

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
    await _ensureFreshAccessToken();
    final uri = userId != null
        ? Uri.parse('$_baseUrl/characters?user_id=$userId')
        : Uri.parse('$_baseUrl/characters');

    final response = await http.get(uri, headers: _authHeaders);

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
    required String userId,
    String? backgroundStory,
    String? appearanceDescription,
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/characters'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'description': description,
        'personality_traits': traits,
        'user_id': userId,
        if (backgroundStory != null && backgroundStory.isNotEmpty)
          'background_story': backgroundStory,
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
    await _ensureFreshAccessToken();
    final response = await http.patch(
      Uri.parse('$_baseUrl/characters/$characterId'),
      headers: _jsonHeaders,
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
    await _ensureFreshAccessToken();
    final uri = Uri.parse('$_baseUrl/characters/$characterId/upload-image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);

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
  Future<Map<String, dynamic>> updateStory(
    String storyId,
    Map<String, dynamic> updates,
  ) async {
    await _ensureFreshAccessToken();
    final response = await http.patch(
      Uri.parse('$_baseUrl/stories/$storyId'),
      headers: _jsonHeaders,
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
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/stories/$storyId/scenes/analyze'),
      headers: _jsonHeaders,
      body: jsonEncode({'content': content, 'character_names': characterNames}),
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
  Future<StoryModel> createStory(
    CreationConfig config, {
    String? userId,
  }) async {
    await _ensureFreshAccessToken();
    final url = Uri.parse('$_baseUrl/stories');

    // Map Config to Backend Request
    final Map<String, dynamic> body = {
      "user_id": userId,
      "genre": _mapGenreToBackend(config.genreLabel),
      "tone": config.toneLabel,
      "narrative_type": config.narrativeType, // 추가
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
      headers: _jsonHeaders,
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
    } else {
      throw Exception(
        'Failed to create story: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Delete Story API
  Future<bool> deleteStory(String storyId) async {
    await _ensureFreshAccessToken();
    final url = Uri.parse('$_baseUrl/stories/$storyId');
    try {
      final response = await http.delete(url, headers: _authHeaders);
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
    await _ensureFreshAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/stories/$storyId/scenes'),
      headers: _authHeaders,
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
    String content, {
    String role = 'ai',
    String sceneType = 'narrative',
  }) async {
    await _ensureFreshAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/stories/$storyId/scenes'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'content': content,
        'chapter_id': null, // Optional
        'role': role,
        'scene_type': sceneType,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['data'];
    } else {
      throw Exception('Failed to create scene: ${response.body}');
    }
  }
}
