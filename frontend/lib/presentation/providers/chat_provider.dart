import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api_service.dart';

// API Provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Chat State
class ChatState {
  final List<Map<String, String>> messages;
  final bool isLoading;

  ChatState({required this.messages, this.isLoading = false});

  ChatState copyWith({List<Map<String, String>>? messages, bool? isLoading}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _apiService;

  ChatNotifier(this._apiService) : super(ChatState(messages: []));

  Future<void> sendMessage(String text) async {
    // Add user message
    state = state.copyWith(
      messages: [
        ...state.messages,
        {'role': 'user', 'content': text},
      ],
      isLoading: true,
    );

    try {
      final responseMap = await _apiService.chat(text);
      final aiText = responseMap['response'] as String;

      // Add AI response
      state = state.copyWith(
        messages: [
          ...state.messages,
          {'role': 'ai', 'content': aiText},
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          {'role': 'system', 'content': 'Error: $e'},
        ],
        isLoading: false,
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(apiServiceProvider));
});
