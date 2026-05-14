import 'card.dart';

class UnoGameState {
  List<UnoCard> drawPile;
  List<UnoCard> discardPile;
  Map<String, List<UnoCard>> playerHands;
  List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;

  UnoGameState({
    required this.drawPile,
    required this.discardPile,
    required this.playerHands,
    required this.playerOrder,
    this.currentPlayerIndex = 0,
    this.isClockwise = true,
    this.winner,
  });

  UnoCard get topCard => discardPile.last;

  int get playerCount => playerOrder.length;

  String get currentPlayer => playerOrder[currentPlayerIndex];

  List<UnoCard> get currentHand => playerHands[currentPlayer] ?? [];

  void nextTurn() {
    if (isClockwise) {
      currentPlayerIndex = (currentPlayerIndex + 1) % playerCount;
    } else {
      currentPlayerIndex = (currentPlayerIndex - 1 + playerCount) % playerCount;
    }
  }

  Map<String, dynamic> toJson() => {
        'drawPileCount': drawPile.length,
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'playerHands': playerHands.map(
          (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
        ),
        'playerOrder': playerOrder,
        'currentPlayerIndex': currentPlayerIndex,
        'isClockwise': isClockwise,
        'winner': winner,
      };

  factory UnoGameState.fromJson(Map<String, dynamic> json) => UnoGameState(
        drawPile: [],
        discardPile: (json['discardPile'] as List)
            .map((c) => UnoCard.fromJson(c))
            .toList(),
        playerHands: (json['playerHands'] as Map).map(
          (k, v) => MapEntry(k, (v as List).map((c) => UnoCard.fromJson(c)).toList()),
        ),
        playerOrder: List<String>.from(json['playerOrder']),
        currentPlayerIndex: json['currentPlayerIndex'],
        isClockwise: json['isClockwise'],
        winner: json['winner'],
      );
}
