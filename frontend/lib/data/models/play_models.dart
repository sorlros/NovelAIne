/// Shapes returned by the skeleton-story endpoints
/// (`/stories/{id}/play` and `/stories/{id}/generation`).
library;

class PlayChoice {
  final String id;
  final String label;

  /// The choice changes the story for good; the app marks it as remembered.
  final bool lasting;

  const PlayChoice({
    required this.id,
    required this.label,
    required this.lasting,
  });

  factory PlayChoice.fromJson(Map<String, dynamic> json) {
    return PlayChoice(
      id: json['id'].toString(),
      label: json['label']?.toString() ?? '',
      lasting: json['lasting'] == true,
    );
  }
}

class PlayStatus {
  final int beatSeq;
  final String? question;
  final List<PlayChoice> choices;

  /// The next part of the story is still being planned on the server.
  final bool preparing;
  final bool finished;
  final List<String> presentCharacters;

  /// Earlier reader choices that the current scene carried forward.
  final List<String> callbacks;

  /// Scene image or BGM generation is still queued or running on the server.
  final bool mediaPending;

  const PlayStatus({
    required this.beatSeq,
    required this.question,
    required this.choices,
    required this.preparing,
    required this.finished,
    required this.presentCharacters,
    required this.callbacks,
    this.mediaPending = false,
  });

  bool get canUndo => beatSeq > 1;

  factory PlayStatus.fromJson(Map<String, dynamic> json) {
    final question = json['question']?.toString();
    return PlayStatus(
      beatSeq: (json['beat_seq'] as num?)?.toInt() ?? 1,
      question: question == null || question.isEmpty ? null : question,
      choices: (json['choices'] as List? ?? const [])
          .map((c) => PlayChoice.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      preparing: json['preparing'] == true,
      finished: json['finished'] == true,
      presentCharacters: List<String>.from(
        json['present_characters'] ?? const [],
      ),
      callbacks: List<String>.from(json['callbacks'] ?? const []),
      mediaPending: json['media_pending'] == true,
    );
  }
}

/// The latest scene's BGM url when it was not there in [before], else null.
String? newLatestSceneBgm(
  List<Map<String, dynamic>> before,
  List<Map<String, dynamic>> after,
) {
  if (after.isEmpty) return null;
  final latest = after.last;
  final url = latest['bgmUrl']?.toString();
  if (url == null || url.isEmpty) return null;
  for (final scene in before) {
    if (scene['id'] == latest['id']) {
      final old = scene['bgmUrl']?.toString();
      return old == null || old.isEmpty ? url : null;
    }
  }
  return url;
}

class GenerationStatus {
  /// queued, running, ready or failed.
  final String status;

  /// The last step that finished: none, world, spine, segment or opening.
  final String step;
  final String? error;

  /// The story's title, set once the world is made (a placeholder before).
  final String? title;

  const GenerationStatus({
    required this.status,
    required this.step,
    this.error,
    this.title,
  });

  static const steps = ['none', 'world', 'spine', 'segment'];

  /// What is being made now, keyed by the last finished step.
  static const stepLabels = {
    'none': '세계와 인물을 짓고 있습니다',
    'world': '이야기의 큰 줄기를 세우고 있습니다',
    'spine': '첫 장면을 준비하고 있습니다',
    'segment': '첫 장면을 쓰고 있습니다',
    'opening': '거의 다 됐습니다',
  };

  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';

  /// Index of the step in progress in [steps]; [steps.length] once all are done.
  int get stepIndex {
    final index = steps.indexOf(step);
    return index == -1 ? steps.length : index;
  }

  String get label => stepLabels[step] ?? stepLabels['none']!;

  factory GenerationStatus.fromJson(Map<String, dynamic> json) {
    return GenerationStatus(
      status: json['status']?.toString() ?? 'queued',
      step: json['step']?.toString() ?? 'none',
      error: json['error']?.toString(),
      title: json['title']?.toString(),
    );
  }
}
