import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/story_markdown.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('parseStoryBlocks', () {
    test('blank lines end paragraphs and a single line break is a space', () {
      final blocks = parseStoryBlocks('첫 줄\n  이어진 줄\n\n\n「대사」\n');
      expect(blocks.map((b) => b.paragraphs), [
        ['첫 줄 이어진 줄'],
        ['「대사」'],
      ]);
      expect(blocks.any((b) => b.quote), isFalse);
    });

    test('quote lines make one quote that keeps its line breaks', () {
      final blocks = parseStoryBlocks('앞 문단\n> 인용 하나\n> 계속\n>\n> 인용 둘\n\n뒤 문단');
      expect(blocks.length, 3);
      expect(blocks[1].quote, isTrue);
      expect(blocks[1].paragraphs, ['인용 하나\n계속', '인용 둘']);
      expect(blocks[2].paragraphs, ['뒤 문단']);
    });

    test('headings and lists stay plain text', () {
      expect(parseStoryBlocks('# 제목\n- 항목').single.paragraphs, ['# 제목 - 항목']);
    });
  });

  group('storySpans', () {
    const base = TextStyle(fontSize: 10, color: Color(0xFFFFFFFF));
    const strong = TextStyle(fontWeight: FontWeight.bold);

    test('bold and italic become their own spans', () {
      final spans = storySpans('그는 **멈췄다**, *아주* 천천히', base, strong);
      expect(spans.map((s) => s.text), ['그는 ', '멈췄다', ', ', '아주', ' 천천히']);
      expect(spans[1].style!.fontWeight, FontWeight.bold);
      expect(spans[3].style!.fontStyle, FontStyle.italic);
      expect(spans[0].style, base);
    });

    test('a lone star or spaced stars stay text', () {
      expect(
        storySpans('별 * 하나와 * 둘', base, strong).map((s) => s.text).join(),
        '별 * 하나와 * 둘',
      );
    });

    test('in a quote the paragraph style wins over the quote style', () {
      const quote = TextStyle(
        fontStyle: FontStyle.italic,
        color: Color(0x80FFFFFF),
      );
      final span = storySpans('인용', base, strong, quote: quote).single;
      expect(span.style!.color, base.color);
      expect(span.style!.fontStyle, FontStyle.italic);
    });
  });

  testWidgets('blocks are 8px apart and quotes are padded by 8px', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StoryMarkdown(
            data: '하나\n\n> 둘',
            style: TextStyle(fontSize: 10),
            strongStyle: TextStyle(fontWeight: FontWeight.bold),
            quoteStyle: TextStyle(fontStyle: FontStyle.italic),
            quoteDecoration: BoxDecoration(),
          ),
        ),
      ),
    );
    final first = tester.getRect(find.text('하나'));
    final second = tester.getRect(find.text('둘'));
    expect(second.top - first.bottom, 8 + 8);
  });
}
