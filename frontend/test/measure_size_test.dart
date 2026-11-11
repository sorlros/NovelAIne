import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/presentation/widgets/measure_size.dart';

void main() {
  testWidgets('reports the child height, and again when it changes', (
    tester,
  ) async {
    final heights = <double>[];
    Future<void> pumpWith(double height) async {
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: MeasureSize(
            onChange: (size) => heights.add(size.height),
            child: SizedBox(width: 100, height: height),
          ),
        ),
      );
      await tester.pump(); // reports arrive after the frame
    }

    await pumpWith(120);
    await pumpWith(120);
    await pumpWith(300);
    expect(heights, [120, 300]);
  });
}
