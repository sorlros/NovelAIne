import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('Capture all UI screens', ($) async {
    $.PumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Home Screen'))),
      ),
    );
    await $.pumpAndSettle();
    await $.native.tapOnText('Home Screen');

    await $.pump(const Duration(seconds: 1));
    await $.native.screenshot(path: 'screenshots/home_screen.png');
  });
}
