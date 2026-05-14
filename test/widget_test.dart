import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_app/screens/home_screen.dart';

void main() {
  testWidgets('На главном экране есть кнопка Начать', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );

    expect(find.text('Добро пожаловать!'), findsOneWidget);
    expect(find.text('Начать'), findsOneWidget);
  });
}
