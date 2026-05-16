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
    if (color == CardColor.wild) return true;
    
    if (type == CardType.clear) {
      return topCard.color == color || topCard.type == CardType.clear;
    }
    
    if (topCard.color == color) return true;
    
    if (topCard.color == CardColor.wild && chosenColor != null && chosenColor == color) {
      return true;
    }
    
    if (topCard.type == type) {
      if (type == CardType.number) {
        return topCard.number == number;
      }
      return true;
    }
    
    final bool isTopDrawCard = topCard.type == CardType.draw2 ||
                               topCard.type == CardType.wildDraw4 ||
                               topCard.type == CardType.wildDraw8;
    
    final bool isMyDrawCard = type == CardType.draw2 ||
                              type == CardType.wildDraw4 ||
                              type == CardType.wildDraw8;
    
    if (isTopDrawCard && isMyDrawCard) {
      if (topCard.type == CardType.draw2) {
        return true;
      }
      
      if (topCard.type == CardType.wildDraw4) {
        if (type == CardType.wildDraw4 || type == CardType.wildDraw8) {
          return true;
        }
        if (type == CardType.draw2) {
          return chosenColor != null && color == chosenColor;
        }
      }
      
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

  bool canRespondToDraw(CardColor? chosenColor, CardType attackCardType) {
    if (type == CardType.wild) return false;
    
    if (attackCardType == CardType.draw2) {
      if (type == CardType.draw2) return true;
      if (type == CardType.wildDraw4) return true;
      if (type == CardType.wildDraw8) return true;
    }
    
    if (attackCardType == CardType.wildDraw4) {
      if (type == CardType.wildDraw4) return true;
      if (type == CardType.wildDraw8) return true;
      if (type == CardType.draw2) {
        return chosenColor != null && color == chosenColor;
      }
    }
    
    if (attackCardType == CardType.wildDraw8) {
      if (type == CardType.wildDraw8) return true;
      if (type == CardType.wildDraw4) return true;
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