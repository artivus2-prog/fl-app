import 'card.dart';

class UnoGameState {
  final List<UnoCard> discardPile;
  final Map<String, List<UnoCard>> playerHands;
  final List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;
  int drawPileCount;
  CardColor? chosenColor; // Цвет, выбранный при +4
  String? pendingResponsePlayer; // Кто должен ответить на +4
  int? pendingDrawCount; // Сколько карт брать если не ответит

  UnoGameState({
    required this.drawPileCount,
    required this.discardPile,
    required this.playerHands,
    required this.playerOrder,
    this.currentPlayerIndex = 0,
    this.isClockwise = true,
    this.winner,
    this.chosenColor,
    this.pendingResponsePlayer,
    this.pendingDrawCount,
  });

  UnoCard get topCard => discardPile.last;
  int get playerCount => playerOrder.length;
  String get currentPlayer => playerOrder[currentPlayerIndex];
  List<UnoCard> currentHand(String player) => playerHands[player] ?? [];

  void nextTurn() {
    if (isClockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1 + playerCount) % playerCount;
    }
  }

  Map<String, dynamic> toJson() => {
    'discardPile': discardPile.map((c) => c.toJson()).toList(),
    'playerHands': playerHands.map(
      (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
    ),
    'playerOrder': playerOrder,
    'currentPlayerIndex': currentPlayerIndex,
    'isClockwise': isClockwise,
    'winner': winner,
    'drawPileCount': drawPileCount,
    'chosenColor': chosenColor?.name,
    'pendingResponsePlayer': pendingResponsePlayer,
    'pendingDrawCount': pendingDrawCount,
  };

  factory UnoGameState.fromJson(Map<String, dynamic> json) => UnoGameState(
    drawPileCount: json['drawPileCount'] ?? 0,
    discardPile: (json['discardPile'] as List)
        .map((c) => UnoCard.fromJson(c))
        .toList(),
    playerHands: (json['playerHands'] as Map).map(
      (k, v) => MapEntry(k, (v as List).map((c) => UnoCard.fromJson(c)).toList()),
    ),
    playerOrder: List<String>.from(json['playerOrder']),
    currentPlayerIndex: json['currentPlayerIndex'] ?? 0,
    isClockwise: json['isClockwise'] ?? true,
    winner: json['winner'],
    chosenColor: json['chosenColor'] != null 
        ? CardColor.values.byName(json['chosenColor']) 
        : null,
    pendingResponsePlayer: json['pendingResponsePlayer'],
    pendingDrawCount: json['pendingDrawCount'],
  );
}
