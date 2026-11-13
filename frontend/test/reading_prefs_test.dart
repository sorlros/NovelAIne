import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/providers/reading_prefs_provider.dart';

void main() {
  test('saved prefs round-trip', () {
    const prefs = ReadingPrefs(
      font: 'Gowun Batang',
      sizeStep: 3,
      spacingStep: 0,
    );
    expect(ReadingPrefs.decode(prefs.encode()), prefs);
  });

  test('unknown font or out-of-range step falls back per part', () {
    final prefs = ReadingPrefs.decode(
      '{"font":"Comic Sans","size":9,"spacing":-1}',
    );
    expect(prefs, const ReadingPrefs());
    final partly = ReadingPrefs.decode('{"font":"Song Myung","size":9}');
    expect(partly.font, 'Song Myung');
    expect(partly.sizeStep, const ReadingPrefs().sizeStep);
  });

  test('broken or missing JSON gives the default', () {
    expect(ReadingPrefs.decode('{oops'), const ReadingPrefs());
    expect(ReadingPrefs.decode('[1]'), const ReadingPrefs());
    expect(ReadingPrefs.decode(null), const ReadingPrefs());
  });
}
