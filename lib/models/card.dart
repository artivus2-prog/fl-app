enum CardColor { red, blue, green, yellow, wild }
enum CardType { number, skip, reverse, draw2, wild, wildDraw4 }

class UnoCard {
  final CardColor color;
  final CardType type;
  final int? number;

  const UnoCard({required this.color, required this.type, this.number});

  bool canPlayOn(UnoCard topCard) {
    if (color == CardColor.wild) return true;
    if (topCard.color == color) return true;
    if (topCard.type == type && type == CardType.number) {
      return topCard.number == number;
    }
    if (topCard.type == type && type != CardType.number) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'type': type.name,
        'number': number,
      };

  factory UnoCard.fromJson(Map<String, dynamic> json) => UnoCard(
        color: CardColor.values.byName(json['color']),
        type: CardType.values.byName(json['type']),
        number: json['number'],
      );
}
