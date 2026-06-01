import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:frontend/main.dart';

void main() {
  patrolTest('Capture auth screen', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await Future<void>.delayed(const Duration(seconds: 1));
  });

  patrolTest('Capture login tab', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  patrolTest('Capture signup tab', ($) async {
    await $.pumpWidgetAndSettle(const MyApp());
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
}
