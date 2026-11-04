import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alqanaa_app/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders logo and title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          onToggleDarkMode: () {},
          isDarkMode: false,
        ),
      ),
    );

    expect(find.text('القناعة'), findsOneWidget);
    expect(find.text('لجملة المواد الغذائية'), findsOneWidget);
  });
}
