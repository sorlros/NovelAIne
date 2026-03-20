import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class WritingEffect extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const WritingEffect({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 30),
  });

  @override
  State<WritingEffect> createState() => _WritingEffectState();
}

class _WritingEffectState extends State<WritingEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration * widget.text.length,
      vsync: this,
    );
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(_controller);
    _controller.forward();
  }

  @override
  void didUpdateWidget(WritingEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.duration = widget.duration * widget.text.length;
      _characterCount = StepTween(begin: 0, end: widget.text.length).animate(_controller);
      if (_controller.status == AnimationStatus.completed) {
         // If it was already finished, just show the full text
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final textToShow = widget.text.substring(0, _characterCount.value);
        return CustomPaint(
          painter: _WritingPainter(
            text: textToShow,
            fullText: widget.text,
            style: widget.style,
            isFinished: _characterCount.value == widget.text.length,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 24),
            width: double.infinity,
          ),
        );
      },
    );
  }
}

class _WritingPainter extends CustomPainter {
  final String text;
  final String fullText;
  final TextStyle style;
  final bool isFinished;

  _WritingPainter({
    required this.text,
    required this.fullText,
    required this.style,
    required this.isFinished,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    textPainter.layout(maxWidth: size.width);
    textPainter.paint(canvas, Offset.zero);

    if (!isFinished && text.isNotEmpty) {
      // Draw a "fountain pen" cursor at the end of the current text
      final lastOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: text.length),
        ui.Rect.zero,
      );

      final Paint penPaint = Paint()
        ..color = style.color?.withValues(alpha: 0.8) ?? Colors.white70
        ..strokeWidth = 2.0
        ..style = PaintingStyle.fill;

      // Draw a simple pen tip (triangle or small diamond)
      final Path penPath = Path()
        ..moveTo(lastOffset.dx, lastOffset.dy)
        ..lineTo(lastOffset.dx + 4, lastOffset.dy - 10)
        ..lineTo(lastOffset.dx - 4, lastOffset.dy - 10)
        ..close();

      canvas.drawPath(penPath, penPaint);
      
      // Add a subtle "ink glow" at the tip
      canvas.drawCircle(
        lastOffset, 
        2.0, 
        Paint()..color = (style.color ?? Colors.purpleAccent).withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WritingPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
