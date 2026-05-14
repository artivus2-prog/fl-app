import 'dart:math';
import 'card.dart';
import 'game_state.dart';

class BotPlayer {
  final Random _random = Random();

  // Бот выбирает какую карту сыграть
  UnoCard? chooseCard(List<UnoCard> hand, UnoCard topCard, CardColor? chosenColor) {
    // Если есть выбранный цвет (после wild) — приоритет этому цвету
    if (chosenColor != null) {
      // Ищем +2 выбранного цвета для ответа на +4
      for (var card in hand) {
        if (card.type == CardType.draw2 && card.color == chosenColor) {
          return card;
        }
      }
    }

    // Ищем играбельные карты
    List<UnoCard> playable = hand.where((c) => c.canPlayOn(topCard)).toList();
    if (playable.isEmpty) return null;

    // Приоритеты:
    // 1. +4 если мало карт у соперника
    // 2. +2
    // 3. Пропуск хода
    // 4. Реверс
    // 5. Обычная карта (предпочитаем сбросить дубли)

    // Ищем дубликаты по числу для множественного сброса
    Map<int, List<UnoCard>> numberGroups = {};
    for (var card in playable) {
      if (card.type == CardType.number) {
        numberGroups.putIfAbsent(card.number!, () => []);
        numberGroups[card.number!]!.add(card);
      }
    }

    // Если есть дубликаты — сбрасываем все
    for (var group in numberGroups.values) {
      if (group.length >= 2) return group.first;
    }

    // Специальные карты
    for (var card in playable) {
      if (card.type == CardType.wildDraw4) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.draw2) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.skip) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.reverse) return card;
    }
    for (var card in playable) {
      if (card.type == CardType.wild) return card;
    }

    // Обычная карта
    return playable.first;
  }

  // Бот выбирает цвет для дикой карты
  CardColor chooseColor(List<UnoCard> hand) {
    // Считаем каких цветов больше
    Map<CardColor, int> colorCount = {};
    for (var card in hand) {
      if (card.color != CardColor.wild) {
        colorCount[card.color] = (colorCount[card.color] ?? 0) + 1;
      }
    }

    if (colorCount.isNotEmpty) {
      // Выбираем цвет, которого больше
      return colorCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Случайный цвет
    return CardColor.values[_random.nextInt(4)];
  }

  bool shouldRespondToDraw4(List<UnoCard> hand, CardColor chosenColor) {
    // Бот отвечает на +4 если есть +2 нужного цвета
    return hand.any((c) => c.type == CardType.draw2 && c.color == chosenColor);
  }
}
