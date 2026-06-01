import 'package:flutter/material.dart';

class InkRevealText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const InkRevealText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 50),
  });

  @override
  State<InkRevealText> createState() => _InkRevealTextState();
}

class _InkRevealTextState extends State<InkRevealText>
    with SingleTickerProviderStateMixin {
  late String _displayedText;

  @override
  void initState() {
    super.initState();
    _displayedText = "";
    _startReveal();
  }

  void _startReveal() async {
    for (int i = 0; i < widget.text.length; i++) {
      if (!mounted) return;
      setState(() {
        _displayedText = widget.text.substring(0, i + 1);
      });
      await Future.delayed(widget.duration);
    }
  }

  @override
  void didUpdateWidget(InkRevealText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // If text changed (e.g. streaming update), just update displayed text
      // to avoid restarting animation from scratch for every chunk.
      _displayedText = widget.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(_displayedText, style: widget.style),
        // Subtle ink bleed/glow effect
        Text(
          _displayedText,
          style: widget.style.copyWith(
            color: widget.style.color?.withValues(alpha: 0.1),
            shadows: [
              Shadow(
                color:
                    widget.style.color?.withValues(alpha: 0.3) ??
                    Colors.white30,
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// A more advanced CustomPainter version could be added here if needed.
