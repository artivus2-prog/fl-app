import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen has start button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );

    // Проверяем, что текст приветствия отображается
    expect(find.text('Добро пожаловать!'), findsOneWidget);
    
    // Проверяем, что кнопка "Начать" есть на экране
    expect(find.text('Начать'), findsOneWidget);
    
    // Нажимаем на кнопку
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    
    // Проверяем, что SnackBar появился
    expect(find.text('Приложение запущено!'), findsOneWidget);
  });
}