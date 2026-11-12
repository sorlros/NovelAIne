import 'package:material_ui/material_ui.dart';

/// A block of scene text: a paragraph, or a `>` quote holding one or more paragraphs.
class StoryBlock {
  final bool quote;
  final List<String> paragraphs;

  const StoryBlock(this.paragraphs, {this.quote = false});
}

final _quoteMarker = RegExp(r'^ {0,3}> ?');
final _softLineBreak = RegExp(r' ?\n *');

/// Splits scene text the way Markdown does for the part scenes use: blank lines end a paragraph,
/// `>` lines make a quote, and a single line break inside a paragraph is a space. Anything else
/// (headings, lists) stays plain text.
List<StoryBlock> parseStoryBlocks(String data) {
  final blocks = <StoryBlock>[];
  var lines = <String>[];
  var quote = false;
  var quoteParagraphs = <String>[];

  void endParagraph() {
    if (lines.isEmpty) return;
    if (quote) {
      quoteParagraphs.add(lines.join('\n'));
    } else {
      final text = lines.join('\n').replaceAll(_softLineBreak, ' ').trim();
      if (text.isNotEmpty) blocks.add(StoryBlock([text]));
    }
    lines = [];
  }

  void endQuote() {
    endParagraph();
    if (quoteParagraphs.isNotEmpty) {
      blocks.add(StoryBlock(quoteParagraphs, quote: true));
    }
    quoteParagraphs = [];
    quote = false;
  }

  for (final line in data.split('\n')) {
    final marker = _quoteMarker.firstMatch(line);
    if (marker != null) {
      if (!quote) {
        endParagraph();
        quote = true;
      }
      final rest = line.substring(marker.end);
      rest.trim().isEmpty ? endParagraph() : lines.add(rest);
    } else if (line.trim().isEmpty) {
      quote ? endQuote() : endParagraph();
    } else {
      if (quote) endQuote();
      lines.add(line);
    }
  }
  quote ? endQuote() : endParagraph();
  return blocks;
}

final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*(?!\s)(.+?)(?<!\s)\*');

/// `**bold**` and `*italic*` spans of one paragraph. In a quote, [quote] lies under every span's style.
List<TextSpan> storySpans(
  String text,
  TextStyle style,
  TextStyle strong, {
  TextStyle? quote,
}) {
  final spans = <TextSpan>[];
  void add(String part, TextStyle partStyle) => spans.add(
    TextSpan(text: part, style: quote?.merge(partStyle) ?? partStyle),
  );
  var start = 0;
  for (final match in _emphasis.allMatches(text)) {
    if (match.start > start) add(text.substring(start, match.start), style);
    match.group(1) != null
        ? add(match.group(1)!, style.merge(strong))
        : add(
            match.group(2)!,
            style.merge(const TextStyle(fontStyle: FontStyle.italic)),
          );
    start = match.end;
  }
  if (start < text.length) add(text.substring(start), style);
  return spans;
}

/// Scene text with the layout flutter_markdown gave it (8px between blocks, quotes padded by 8px),
/// so scenes look as they did. Quote text takes [quoteStyle] under the paragraph style, as it did there.
class StoryMarkdown extends StatelessWidget {
  final String data;
  final TextStyle style;
  final TextStyle strongStyle;
  final TextStyle quoteStyle;
  final BoxDecoration quoteDecoration;

  const StoryMarkdown({
    super.key,
    required this.data,
    required this.style,
    required this.strongStyle,
    required this.quoteStyle,
    required this.quoteDecoration,
  });

  Widget _paragraph(String text, {TextStyle? quote}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SelectableText.rich(
              TextSpan(
                children: storySpans(text, style, strongStyle, quote: quote),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _spaced(Iterable<Widget> children) => [
    for (final (index, child) in children.indexed) ...[
      if (index > 0) const SizedBox(height: 8),
      child,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        for (final block in parseStoryBlocks(data))
          block.quote
              ? DecoratedBox(
                  decoration: quoteDecoration,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _spaced(
                        block.paragraphs.map(
                          (text) => _paragraph(text, quote: quoteStyle),
                        ),
                      ),
                    ),
                  ),
                )
              : _paragraph(block.paragraphs.single),
      ]),
    );
  }
}
