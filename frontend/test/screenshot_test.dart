import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Placeholder screenshot surface renders in widget tests', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Home Screen'))),
      ),
    );

    expect(find.text('Home Screen'), findsOneWidget);
  });
}
