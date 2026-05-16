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

  // ========== ПРОВЕРКА ХОДА ==========
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
    
    // 5. Совпадение по типу (число, пропуск, реверс)
    if (topCard.type == type) {
      if (type == CardType.number) {
        return topCard.number == number;
      }
      // skip, reverse - одинаковый тип
      return true;
    }
    
    // 6. ДОБОРНЫЕ КАРТЫ: специальная логика
    final bool isTopDrawCard = topCard.type == CardType.draw2 ||
                               topCard.type == CardType.wildDraw4 ||
                               topCard.type == CardType.wildDraw8;
    
    final bool isMyDrawCard = type == CardType.draw2 ||
                              type == CardType.wildDraw4 ||
                              type == CardType.wildDraw8;
    
    if (isTopDrawCard && isMyDrawCard) {
      // На +2 можно ответить ЛЮБОЙ доборной картой (+2, +4, +8)
      if (topCard.type == CardType.draw2) {
        return true;
      }
      
      // На +4 (с выбранным цветом)
      if (topCard.type == CardType.wildDraw4) {
        // +4 и +8 можно ответить всегда (любые цвета)
        if (type == CardType.wildDraw4 || type == CardType.wildDraw8) {
          return true;
        }
        // +2 можно ответить ТОЛЬКО если цвет совпадает с выбранным
        if (type == CardType.draw2) {
          return chosenColor != null && color == chosenColor;
        }
      }
      
      // На +8 (с выбранным цветом)
      if (topCard.type == CardType.wildDraw8) {
        // +8 и +4 можно ответить всегда (любые цвета)
        if (type == CardType.wildDraw8 || type == CardType.wildDraw4) {
          return true;
        }
        // +2 можно ответить ТОЛЬКО если цвет совпадает с выбранным
        if (type == CardType.draw2) {
          return chosenColor != null && color == chosenColor;
        }
      }
    }
    
    return false;
  }

  // ========== ПРОВЕРКА МОЖНО ЛИ ОТВЕТИТЬ НА ДОБОР ==========
  // ⭐ ИСПРАВЛЕНО по вашим правилам
  bool canRespondToDraw(CardColor? chosenColor, CardType attackCardType) {
    // Обычная Wild карта (W) НЕ может отвечать на добор!
    if (type == CardType.wild) return false;
    
    // ===== НА +2 можно ответить ЛЮБОЙ доборной =====
    if (attackCardType == CardType.draw2) {
      if (type == CardType.draw2) return true;
      if (type == CardType.wildDraw4) return true;
      if (type == CardType.wildDraw8) return true;
    }
    
    // ===== НА +4 (с выбранным цветом) =====
    if (attackCardType == CardType.wildDraw4) {
      // +4 и +8 можно ответить всегда
      if (type == CardType.wildDraw4) return true;
      if (type == CardType.wildDraw8) return true;
      // +2 можно ответить ТОЛЬКО если цвет совпадает
      if (type == CardType.draw2) {
        return chosenColor != null && color == chosenColor;
      }
    }
    
    // ===== НА +8 (с выбранным цветом) =====
    if (attackCardType == CardType.wildDraw8) {
      // +8 и +4 можно ответить всегда
      if (type == CardType.wildDraw8) return true;
      if (type == CardType.wildDraw4) return true;
      // +2 можно ответить ТОЛЬКО если цвет совпадает
      if (type == CardType.draw2) {
        return chosenColor != null && color == chosenColor;
      }
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
      cards.add(UnoCard(color: color, type: CardType.clear));
      cards.add(UnoCard(color: color, type: CardType.clear));
    }
    
    for (int i = 0; i < 4; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wild));
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw4));
    }
    
    for (int i = 0; i < 2; i++) {
      cards.add(UnoCard(color: CardColor.wild, type: CardType.wildDraw8));
    }
  }

  void shuffle() {
    cards.shuffle(_random);
  }

  UnoCard draw() {
    if (cards.isEmpty) {
      debugPrint('🔄 Колода пуста! Создаём новую...');
      _createDeck();
      shuffle();
    }
    return cards.removeAt(0);
  }

  List<UnoCard> drawMultiple(int count) {
    List<UnoCard> drawn = [];
    for (int i = 0; i < count; i++) {
      if (cards.isEmpty) {
        debugPrint('🔄 Колода пуста! Создаём новую...');
        _createDeck();
        shuffle();
      }
      drawn.add(draw());
    }
    return drawn;
  }
  
  int get cardCount => cards.length;
  
  void rebuildFromDiscard(List<UnoCard> discardPile, {UnoCard? keepTopCard}) {
    if (discardPile.length <= 1) return;
    
    List<UnoCard> newCards = [];
    for (int i = 0; i < discardPile.length - 1; i++) {
      newCards.add(discardPile[i]);
    }
    
    discardPile.clear();
    if (keepTopCard != null) {
      discardPile.add(keepTopCard);
    }
    
    cards.addAll(newCards);
    shuffle();
    
    debugPrint('🔄 Колода пересоздана из сброса: ${cards.length} карт');
  }
}