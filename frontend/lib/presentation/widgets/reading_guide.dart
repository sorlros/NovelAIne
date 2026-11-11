import 'package:flutter/material.dart';

/// One stop of the guide: the widget under [target] is lit and [text] explains it.
class GuideStep {
  final GlobalKey target;
  final String text;

  /// Brings the target on screen first (e.g. scrolls the list to it); the step is skipped if it is still missing.
  final Future<void> Function()? reveal;

  const GuideStep({required this.target, required this.text, this.reveal});
}

/// Dims the screen, lights one control at a time and says in a line what it does.
class ReadingGuide extends StatefulWidget {
  final List<GuideStep> steps;
  final VoidCallback onDone;

  const ReadingGuide({super.key, required this.steps, required this.onDone});

  @override
  State<ReadingGuide> createState() => _ReadingGuideState();
}

class _ReadingGuideState extends State<ReadingGuide> {
  static const _accent = Color(0xFF7C3AED);
  static const _padding = 8.0;

  int _index = -1;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _goTo(0);
  }

  Future<void> _goTo(int index) async {
    for (var i = index; i < widget.steps.length; i++) {
      final step = widget.steps[i];
      if (step.reveal != null) await step.reveal!();
      if (!mounted) return;
      // Wait a frame so a scroll the reveal started has laid the target out.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final hole = _rectOf(step.target);
      if (hole != null) {
        setState(() {
          _index = i;
          _hole = hole;
        });
        return;
      }
    }
    widget.onDone();
  }

  Rect? _rectOf(GlobalKey key) {
    final target = key.currentContext?.findRenderObject();
    final overlay = context.findRenderObject();
    if (target is! RenderBox || !target.hasSize || overlay is! RenderBox) {
      return null;
    }
    final topLeft = target.localToGlobal(Offset.zero, ancestor: overlay);
    return (topLeft & target.size).inflate(_padding);
  }

  @override
  Widget build(BuildContext context) {
    final target = _hole;
    if (_index < 0 || target == null) {
      // Block taps while the first target is being found.
      return const ModalBarrier(dismissible: false, color: Colors.black54);
    }
    final last = _index == widget.steps.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final hole = target.intersect(Offset.zero & size);
        const cardWidth = 320.0;
        const cardRoom = 150.0;
        final roomBelow = size.height - hole.bottom;
        // A target taller than the screen (a long scene) leaves no room: the card sits over its bottom.
        final over = roomBelow < cardRoom && hole.top < cardRoom;
        final below = !over && roomBelow >= hole.top;
        final left = (hole.center.dx - cardWidth / 2).clamp(
          16.0,
          (size.width - cardWidth - 16).clamp(16.0, double.infinity),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    () {}, // the dimmed screen is not usable during the guide
                child: CustomPaint(painter: _DimPainter(hole)),
              ),
            ),
            Positioned(
              left: left,
              width: (size.width - 32).clamp(0.0, cardWidth),
              top: below ? hole.bottom + 12 : null,
              bottom: over ? 24 : (below ? null : size.height - hole.top + 12),
              child: Material(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.steps[_index].text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${_index + 1} / ${widget.steps.length}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (!last)
                            TextButton(
                              onPressed: widget.onDone,
                              child: const Text(
                                '건너뛰기',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          TextButton(
                            onPressed: last
                                ? widget.onDone
                                : () => _goTo(_index + 1),
                            child: Text(
                              last ? '시작하기' : '다음',
                              style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect hole;

  _DimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final lit = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, dim, lit),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(12)),
      Paint()
        ..color = const Color(0xFF7C3AED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}
