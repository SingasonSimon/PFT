// lib/models/category.dart

class Category {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'
  final int? iconCodePoint;
  final int? colorValue;

  Category({
    this.id,
    required this.name,
    this.type = 'expense', // Default to 'expense' for backward compatibility
    this.iconCodePoint,
    this.colorValue,
  });

  // copyWith method to easily create a modified copy of a category
  Category copyWith({
    int? id,
    String? name,
    String? type,
    int? iconCodePoint,
    int? colorValue,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'] ?? 'expense', // Safely handle older data that might not have a type
      iconCodePoint: map['iconCodePoint'],
      colorValue: map['colorValue'],
    );
  }
}
