import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/reading_prefs_store.dart';

/// Faces the story text can be set in.
const List<String> readingFonts = [
  'Noto Serif KR',
  'Gowun Batang',
  'Nanum Myeongjo',
  'Song Myung',
  'Gowun Dodum',
  'EB Garamond',
  'JetBrains Mono',
];

/// How the story text is set: the face, a size step and a spacing step. Kept on the device.
@immutable
class ReadingPrefs {
  /// Text sizes from small to large, as factors of the reading screen's base size.
  static const List<double> sizes = [0.88, 1.0, 1.12, 1.25];

  /// Line heights from tight to loose.
  static const List<double> spacings = [1.6, 1.8, 2.0];

  static const List<String> sizeLabels = ['작게', '보통', '크게', '아주 크게'];
  static const List<String> spacingLabels = ['좁게', '보통', '넓게'];

  final String font;
  final int sizeStep;
  final int spacingStep;

  const ReadingPrefs({
    this.font = 'Noto Serif KR',
    this.sizeStep = 1,
    this.spacingStep = 1,
  });

  double get scale => sizes[sizeStep];
  double get lineHeight => spacings[spacingStep];

  ReadingPrefs copyWith({String? font, int? sizeStep, int? spacingStep}) {
    return ReadingPrefs(
      font: font ?? this.font,
      sizeStep: sizeStep ?? this.sizeStep,
      spacingStep: spacingStep ?? this.spacingStep,
    );
  }

  String encode() =>
      jsonEncode({'font': font, 'size': sizeStep, 'spacing': spacingStep});

  /// What a device saved; anything it does not know gives the default for that part.
  factory ReadingPrefs.decode(String? saved) {
    const fallback = ReadingPrefs();
    if (saved == null || saved.isEmpty) return fallback;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      int step(Object? value, int count, int otherwise) =>
          value is int && value >= 0 && value < count ? value : otherwise;
      final font = json['font'];
      return ReadingPrefs(
        font: readingFonts.contains(font) ? font as String : fallback.font,
        sizeStep: step(json['size'], sizes.length, fallback.sizeStep),
        spacingStep: step(
          json['spacing'],
          spacings.length,
          fallback.spacingStep,
        ),
      );
    } catch (_) {
      return fallback;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingPrefs &&
      other.font == font &&
      other.sizeStep == sizeStep &&
      other.spacingStep == spacingStep;

  @override
  int get hashCode => Object.hash(font, sizeStep, spacingStep);
}

class ReadingPrefsNotifier extends StateNotifier<ReadingPrefs> {
  ReadingPrefsNotifier(String? saved) : super(ReadingPrefs.decode(saved));

  void set(ReadingPrefs prefs) {
    if (prefs == state) return;
    state = prefs;
    ReadingPrefsStore().write(prefs.encode());
  }
}

/// Overridden in `main` with what the device kept, so the first story opens as the reader left it.
final readingPrefsProvider =
    StateNotifierProvider<ReadingPrefsNotifier, ReadingPrefs>(
      (ref) => ReadingPrefsNotifier(null),
    );
