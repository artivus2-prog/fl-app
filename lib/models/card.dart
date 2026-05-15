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

  // ========== ПРАВИЛЬНАЯ ЛОГИКА ПРОВЕРКИ ХОДА ==========
  bool canPlayOn(UnoCard topCard, {CardColor? chosenColor}) {
    // 1. Дикие карты (W, +4, +8) всегда можно сыграть на любую карту
    if (color == CardColor.wild) return true;
    
    // 2. Clear: можно на свой цвет или на другую clear
    if (type == CardType.clear) {
      return topCard.color == color || topCard.type == CardType.clear;
    }
    
    // 3. Совпадение по цвету
    if (topCard.color == color) return true;
    
    // 4. Если верхняя карта - дикая, используем выбранный цвет
    if (topCard.color == CardColor.wild && chosenColor != null && chosenColor == color) {
      return true;
    }
    
    // 5. Совпадение по типу (число, пропуск, реверс, доборные)
    if (topCard.type == type) {
      if (type == CardType.number) {
        return topCard.number == number;
      }
      // skip, reverse, draw2 - одинаковый тип
      return true;
    }
    
    // 6. ДОБОРНЫЕ КАРТЫ: можно ответить любой доборной на любую доборную
    // +2 можно ответить +4, +8 (любого цвета)
    // +4 можно ответить +4, +8 (любого цвета) или +2 ТОЛЬКО если цвет совпадает
    // +8 можно ответить +8, +4 (любого цвета) или +2 ТОЛЬКО если цвет совпадает
    
    final bool isTopDrawCard = topCard.type == CardType.draw2 ||
                               topCard.type == CardType.wildDraw4 ||
                               topCard.type == CardType.wildDraw8;
    
    final bool isMyDrawCard = type == CardType.draw2 ||
                              type == CardType.wildDraw4 ||
                              type == CardType.wildDraw8;
    
    if (isTopDrawCard && isMyDrawCard) {
      // +2 на +2, +4, +8 - всегда можно (любые цвета)
      if (topCard.type == CardType.draw2) {
        return true;
      }
      
      // +4 на +4, +8 - всегда можно (любые цвета)
      // +4 на +2 - только если цвет совпадает с выбранным
      if (topCard.type == CardType.wildDraw4) {
        if (type == CardType.wildDraw4 || type == CardType.wildDraw8) {
          return true;
        }
        if (type == CardType.draw2) {
          return chosenColor != null && color == chosenColor;
        }
      }
      
      // +8 на +8, +4 - всегда можно (любые цвета)
      // +8 на +2 - только если цвет совпадает с выбранным
      if (topCard.type == CardType.wildDraw8) {
        if (type == CardType.wildDraw8 || type == CardType.wildDraw4) {
          return true;
        }
        if (type == CardType.draw2) {
          return chosenColor != null && color == chosenColor;
        }
      }
    }
    
    return false;
  }

  // ========== ПРОВЕРКА МОЖНО ЛИ ОТВЕТИТЬ НА ДОБОР ==========
  bool canRespondToDraw(CardColor? chosenColor, CardType attackCardType) {
    // +2 на +2
    if (type == CardType.draw2 && attackCardType == CardType.draw2) {
      return true;
    }
    
    // +2 на +4 (нужен совпадающий цвет)
    if (type == CardType.draw2 && attackCardType == CardType.wildDraw4) {
      return chosenColor != null && color == chosenColor;
    }
    
    // +2 на +8 (нужен совпадающий цвет)
    if (type == CardType.draw2 && attackCardType == CardType.wildDraw8) {
      return chosenColor != null && color == chosenColor;
    }
    
    // +4 на +4
    if (type == CardType.wildDraw4 && attackCardType == CardType.wildDraw4) {
      return true;
    }
    
    // +4 на +8
    if (type == CardType.wildDraw4 && attackCardType == CardType.wildDraw8) {
      return true;
    }
    
    // +8 на +4
    if (type == CardType.wildDraw8 && attackCardType == CardType.wildDraw4) {
      return true;
    }
    
    // +8 на +8
    if (type == CardType.wildDraw8 && attackCardType == CardType.wildDraw8) {
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
    // Стандартные карты 0-9
    for (var color in [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow]) {
      // 0 - одна карта
      cards.add(UnoCard(color: color, type: CardType.number, number: 0));
      // 1-9 - по две карты
      for (int i = 1; i <= 9; i++) {
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
        cards.add(UnoCard(color: color, type: CardType.number, number: i));
      }
      // Действия
      for (int i = 0; i < 2; i++) {
        cards.add(UnoCard(color: color, type: CardType.skip));
        cards.add(UnoCard(color: color, type: CardType.reverse));
        cards.add(UnoCard(color: color, type: CardType.draw2));
      }
      // Clear карты
      cards.add(UnoCard(color: color, type: CardType.clear));
      cards.add(UnoCard(color: color, type: CardType.clear));
    }
    // Дикие карты
    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw4));
    }
    // +8 карты
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