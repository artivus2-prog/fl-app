import 'dart:math';
import 'card.dart';

class BotPlayer {
  final Random _random = Random();

  UnoCard? chooseCard(List<UnoCard> hand, UnoCard topCard, CardColor? chosenColor) {
    if (chosenColor != null) {
      for (var card in hand) {
        if ((card.type == CardType.draw2 || card.type == CardType.wildDraw4 || card.type == CardType.wildDraw8) && card.color == chosenColor) {
          return card;
        }
      }
    }
    List<UnoCard> playable = hand.where((c) => c.canPlayOn(topCard, chosenColor: chosenColor)).toList();
    if (playable.isEmpty) return null;
    Map<int, List<UnoCard>> numberGroups = {};
    for (var card in playable) {
      if (card.type == CardType.number) {
        numberGroups.putIfAbsent(card.number!, () => []);
        numberGroups[card.number!]!.add(card);
      }
    }
    for (var group in numberGroups.values) {
      if (group.length >= 2) return group.first;
    }
    for (var card in playable) { if (card.type == CardType.wildDraw8) return card; }
    for (var card in playable) { if (card.type == CardType.wildDraw4) return card; }
    for (var card in playable) { if (card.type == CardType.draw2) return card; }
    for (var card in playable) { if (card.type == CardType.skip) return card; }
    for (var card in playable) { if (card.type == CardType.reverse) return card; }
    for (var card in playable) { if (card.type == CardType.wild) return card; }
    return playable.first;
  }

  bool shouldRespondToDraw4(List<UnoCard> hand, CardColor? chosenColor) {
    if (chosenColor == null) return false;
    return hand.any((c) => (c.type == CardType.draw2 || c.type == CardType.wildDraw4 || c.type == CardType.wildDraw8) && c.color == chosenColor);
  }

  UnoCard? chooseResponseCard(List<UnoCard> hand, CardColor chosenColor) {
    for (var card in hand) {
      if (card.type == CardType.wildDraw8 && card.color == chosenColor) return card;
    }
    for (var card in hand) {
      if (card.type == CardType.wildDraw4 && card.color == chosenColor) return card;
    }
    for (var card in hand) {
      if (card.type == CardType.draw2 && card.color == chosenColor) return card;
    }
    return null;
  }

  CardColor chooseColor(List<UnoCard> hand) {
    Map<CardColor, int> colorCount = {};
    for (var card in hand) {
      if (card.color != CardColor.wild) {
        colorCount[card.color] = (colorCount[card.color] ?? 0) + 1;
      }
    }
    if (colorCount.isNotEmpty) {
      return colorCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
    return CardColor.values[_random.nextInt(4)];
  }
}
