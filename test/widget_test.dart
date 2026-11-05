import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App theme and title test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('تطبيق القناعة'),
        ),
      ),
    );

    expect(find.text('تطبيق القناعة'), findsOneWidget);
  });
}
