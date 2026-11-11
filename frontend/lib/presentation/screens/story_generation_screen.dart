import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/play_models.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_repository.dart';
import '../../data/services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../widgets/custom_toast.dart';
import 'story_screen.dart';

const _accent = Color(0xFF7C3AED);

/// Shows a skeleton story's generation progress until it can be read.
/// Generation runs on the server; leaving this screen only stops polling.
class StoryGenerationScreen extends ConsumerStatefulWidget {
  final StoryModel story;

  /// Protagonist picture chosen in the wizard. The characters only exist once
  /// generation is done, so it is uploaded then (lost if the screen is left).
  final Uint8List? protagonistImage;

  const StoryGenerationScreen({
    super.key,
    required this.story,
    this.protagonistImage,
  });

  @override
  ConsumerState<StoryGenerationScreen> createState() =>
      _StoryGenerationScreenState();
}

class _StoryGenerationScreenState extends ConsumerState<StoryGenerationScreen> {
  static const _pollInterval = Duration(seconds: 2);

  final ApiService _apiService = ApiService();
  Timer? _timer;
  GenerationStatus? _status;
  bool _retrying = false;
  bool _opening = false;
  bool _connectionLost = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final status = await _apiService.fetchGeneration(widget.story.id);
      if (!mounted) return;
      setState(() {
        _status = status;
        _connectionLost = false;
      });
      if (status.isReady) {
        await _openStory();
      } else if (status.isFailed) {
        _timer?.cancel();
      }
    } catch (error) {
      debugPrint('Generation status failed: $error');
      if (mounted) setState(() => _connectionLost = true);
    }
  }

  Future<void> _openStory() async {
    if (_opening) return;
    _opening = true;
    _timer?.cancel();
    final story = await _readyStory();
    await _uploadProtagonistImage();
    if (!mounted) return;
    ref.invalidate(storiesProvider);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => StoryScreen(initialStory: story)),
    );
  }

  /// The finished story (title and status changed during generation), cached for the home list.
  Future<StoryModel> _readyStory() async {
    try {
      final story = StoryModel.fromJson(
        await _apiService.fetchStory(widget.story.id),
      );
      final userId = ref.read(authProvider).value?.id;
      await ref.read(storyRepositoryProvider).cacheStory(story, userId: userId);
      return story;
    } catch (error) {
      debugPrint('Ready story fetch failed: $error');
      return widget.story;
    }
  }

  Future<void> _uploadProtagonistImage() async {
    final image = widget.protagonistImage;
    if (image == null) return;
    try {
      final storyData = await _apiService.fetchStory(widget.story.id);
      final characters = List<Map<String, dynamic>>.from(
        storyData['characters'] ?? const [],
      );
      if (characters.isEmpty) return;
      final protagonist = characters.firstWhere(
        (c) => c['role_in_story'] == 'protagonist',
        orElse: () => characters.first,
      );
      final id = protagonist['id'].toString();
      await _apiService.uploadCharacterImage(
        id,
        image,
        fileName: 'protagonist_${id.substring(0, 8)}.jpg',
      );
    } catch (error) {
      debugPrint('Protagonist image upload failed: $error');
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final status = await _apiService.retryGeneration(widget.story.id);
      if (!mounted) return;
      setState(() => _status = status);
      _startPolling();
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          ApiException.messageOf(error),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: '나가기',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: status != null && status.isFailed
                ? _FailedView(
                    error: status.error,
                    retrying: _retrying,
                    onRetry: _retry,
                  )
                : _ProgressView(
                    title: status?.title ?? widget.story.title,
                    status: status,
                    connectionLost: _connectionLost,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  final String title;
  final GenerationStatus? status;
  final bool connectionLost;

  const _ProgressView({
    required this.title,
    required this.status,
    required this.connectionLost,
  });

  @override
  Widget build(BuildContext context) {
    final current = status?.stepIndex ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSerif(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status?.label ?? GenerationStatus.stepLabels['none']!,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < GenerationStatus.steps.length; i++)
          _StepRow(
            label: GenerationStatus.stepLabels[GenerationStatus.steps[i]]!,
            done: i < current,
            active: i == current,
          ),
        const SizedBox(height: 28),
        const Text(
          '몇 분 정도 걸립니다. 나가도 계속 만들어지고, 완성되면 홈의 내 이야기에서 열 수 있습니다.',
          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
        ),
        if (connectionLost)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '서버와 연결이 끊겼습니다. 다시 연결을 시도하고 있습니다.',
              style: TextStyle(color: Color(0xFFFFD166), fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final Widget marker = done
        ? const Icon(Icons.check_circle_rounded, color: _accent, size: 20)
        : active
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          )
        : const Icon(
            Icons.radio_button_unchecked,
            color: Colors.white24,
            size: 20,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          marker,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done || active ? Colors.white : Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  final String? error;
  final bool retrying;
  final VoidCallback onRetry;

  const _FailedView({
    required this.error,
    required this.retrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이야기를 만들지 못했습니다',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          error ?? '잠시 후 다시 시도해 주세요.',
          style: const TextStyle(color: Colors.white70, height: 1.6),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: retrying ? null : onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(retrying ? '다시 시작하는 중...' : '다시 시도'),
          style: FilledButton.styleFrom(backgroundColor: _accent),
        ),
      ],
    );
  }
}
