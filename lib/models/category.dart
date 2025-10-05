// Category model represents a spending or income category, including icon and color information.

class Category {
  final int? id;
  final String name;
  final int? iconCodePoint;
  final int? colorValue;

  Category({
    this.id,
    required this.name,
    this.iconCodePoint,
    this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorValue: map['colorValue'],
    );
  }
}
