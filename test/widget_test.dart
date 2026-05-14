import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_app/screens/home_screen.dart';

void main() {
  testWidgets('Главный экран: есть кнопки', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Создать игру'), findsOneWidget);
    expect(find.text('Подключиться к игре'), findsOneWidget);
    expect(find.text('УНО'), findsOneWidget);
  });
}
