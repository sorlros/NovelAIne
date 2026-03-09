import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:frontend/main.dart' as app;

void main() {
  patrolTest('Auth -> Home -> Profile flow', ($) async {
    // 1. Launch the app
    app.main();
    await $.pumpAndSettle();

    // Ensure we are on the Auth Screen by looking for the Login Tab
    expect($('로그인'), findsOneWidget);

    // 2. Perform Login (Since we are using mock logic or basic API without tight validation for test)
    // Enter email
    await $(TextField).at(0).enterText('test@novelaine.com');
    // Enter password
    await $(TextField).at(1).enterText('password123');

    // Tap Login button
    await $('로그인 시작').tap(andSettle: true);

    // 3. Verify Home Screen loaded
    // Look for the "계속 쓰기" (Continue Writing) header introduced in the new UI
    expect($('계속 쓰기'), findsOneWidget);
    expect($('추천 테마'), findsOneWidget);

    // 4. Navigate to Profile Screen via Bottom Nav Bar
    // Tap the standard Profile icon index (last item = 2)
    await $(Icons.person_outline).tap(andSettle: true);

    // 5. Verify Profile Screen loaded
    expect($('창작 스토리'), findsOneWidget);
    expect($('내 캐릭터'), findsOneWidget);

    // Optional: Tap Settings icon to verify navigation
    await $(Icons.settings).tap(andSettle: true);
    expect($('일반 설정'), findsOneWidget);

    // Go back
    await $(Icons.arrow_back).tap(andSettle: true);

    // Sign out
    await $(Icons.logout).tap(andSettle: true);

    // Ensure we are back to Auth Screen
    expect($('로그인'), findsOneWidget);
  });
}
