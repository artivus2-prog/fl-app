import 'dart:math';
import 'package:flutter/material.dart';

enum CardColor { red, blue, green, yellow, wild }
enum CardType { number, skip, reverse, draw2, wild, wildDraw4, wildDraw8, clear }

class UnoCard {
  final CardColor color;
  final CardType type;
  final int? number;
  final String id;

  UnoCard({
    required this.color,
    required this.type,
    this.number,
  }) : id = '${color.name}_${type.name}_${number ?? ""}_${Random().nextInt(10000)}';

  bool canPlayOn(UnoCard topCard, {CardColor? chosenColor}) {
    // Дикие карты (W, +4, +8) всегда можно сыграть на любую карту
    if (color == CardColor.wild) return true;
    
    // Clear: можно на свой цвет или на другую clear
    if (type == CardType.clear) {
      return topCard.color == color || topCard.type == CardType.clear;
    }
    
    // Совпадение по цвету
    if (topCard.color == color) return true;
    
    // Если верхняя карта - дикая, используем выбранный цвет
    // Это нужно для случая, когда на +4 кидают +2 (цвет должен совпадать с выбранным)
    if (topCard.color == CardColor.wild && chosenColor != null && chosenColor == color) {
      return true;
    }
    
    // Совпадение по типу/числу
    if (topCard.type == type) {
      if (type == CardType.number) {
        return topCard.number == number;
      }
      // skip, reverse, draw2 - одинаковый тип
      return true;
    }
    
    return false;
  }

  Color get displayColor {
    switch (color) {
      case CardColor.red: return const Color(0xFFD50000);
      case CardColor.blue: return const Color(0xFF2962FF);
      case CardColor.green: return const Color(0xFF00C853);
      case CardColor.yellow: return const Color(0xFFFFD600);
      case CardColor.wild: return const Color(0xFF1A1A1A);
    }
  }

  String get displayText {
    switch (type) {
      case CardType.number: return '$number';
      case CardType.skip: return '⊘';
      case CardType.reverse: return '⟲';
      case CardType.draw2: return '+2';
      case CardType.wild: return 'W';
      case CardType.wildDraw4: return '+4';
      case CardType.wildDraw8: return '+8';
      case CardType.clear: return '🧹';
    }
  }

  Map<String, dynamic> toJson() => {
    'color': color.name,
    'type': type.name,
    'number': number,
    'id': id,
  };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
    color: CardColor.values.byName(json['color']),
    type: CardType.values.byName(json['type']),
    number: json['number'],
  );
}

class UnoDeck {
  List<UnoCard> cards = [];
  final Random _random;

  UnoDeck({int? seed}) : _random = Random(seed ?? DateTime.now().millisecondsSinceEpoch) {
    _createDeck();
    shuffle();
  }

  void _createDeck() {
    cards.clear();
    // Стандартные карты
    for (var color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      cards.add(UnoCard(color: color, type: CardType.number, number: 0));
      for (int i = 1; i <= 9; i++) {
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
      }
      for (int i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, type: CardType.skip));
        cards.add(UnoCard(color: color, type: CardType.reverse));
        cards.add(UnoCard(color: color, type: CardType.draw2));
      }
      // По 2 clear карты каждого цвета
      cards.add(UnoCard(color: color, type: CardType.clear));
      cards.add(UnoCard(color: color, type: CardType.clear));
    }
    // Дикие карты
    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw4));
    }
    // 2 карты +8
    for (int i = 0; i < 2; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw8));
    }
  }

  void shuffle() {
    cards.shuffle(_random);
  }

  UnoCard draw() {
    if (cards.isEmpty) {
      _createDeck();
      shuffle();
    }
    return cards.removeAt(0);
  }

  List<UnoCard> drawMultiple(int count) {
    return List.generate(count, (_) => draw());
  }
}