// lib/models/transaction.dart

class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final int? categoryId;
  // NEW: Property for 'business' or 'personal' tag
  final String tag;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
    // Set a default value for the new tag
    this.tag = 'business',
  });

  // NEW: A 'copyWith' method for easily creating modified copies
  Transaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? date,
    int? categoryId,
    String? tag,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      tag: tag ?? this.tag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
      'category_id': categoryId,
      // Add the new tag to the map
      'tag': tag,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      description: map['description'],
      date: map['date'],
      categoryId: map['category_id'],
      // Read the tag from the map, with a fallback for older data
      tag: map['tag'] ?? 'business',
    );
  }
}