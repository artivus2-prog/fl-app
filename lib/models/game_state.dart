import 'card.dart';

class UnoGameState {
  final List<UnoCard> discardPile;
  final Map<String, List<UnoCard>> playerHands;
  final List<String> playerOrder;
  int currentPlayerIndex;
  bool isClockwise;
  String? winner;
  int drawPileCount;
  CardColor? chosenColor;
  String? pendingResponsePlayer;
  int? pendingDrawCount;
  CardType? pendingAttackCardType;

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
    this.pendingAttackCardType,
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
    'pendingAttackCardType': pendingAttackCardType?.name,
  };

  factory UnoGameState.fromJson(Map<String, dynamic> json) {
    return UnoGameState(
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
      pendingAttackCardType: json['pendingAttackCardType'] != null 
          ? CardType.values.byName(json['pendingAttackCardType']) 
          : null,
    );
  }
  
  // ⭐ ДОБАВЬТЕ ЭТОТ МЕТОД ДЛЯ КОПИРОВАНИЯ
  UnoGameState copyWith({
    List<UnoCard>? discardPile,
    Map<String, List<UnoCard>>? playerHands,
    List<String>? playerOrder,
    int? currentPlayerIndex,
    bool? isClockwise,
    String? winner,
    int? drawPileCount,
    CardColor? chosenColor,
    String? pendingResponsePlayer,
    int? pendingDrawCount,
    CardType? pendingAttackCardType,
  }) {
    return UnoGameState(
      discardPile: discardPile ?? this.discardPile,
      playerHands: playerHands ?? this.playerHands,
      playerOrder: playerOrder ?? this.playerOrder,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      isClockwise: isClockwise ?? this.isClockwise,
      winner: winner ?? this.winner,
      drawPileCount: drawPileCount ?? this.drawPileCount,
      chosenColor: chosenColor ?? this.chosenColor,
      pendingResponsePlayer: pendingResponsePlayer ?? this.pendingResponsePlayer,
      pendingDrawCount: pendingDrawCount ?? this.pendingDrawCount,
      pendingAttackCardType: pendingAttackCardType ?? this.pendingAttackCardType,
    );
  }
}