// Transaction model represents a financial transaction, including type, amount, and category.

class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final int? categoryId;
  // Indicates whether the transaction is tagged as 'business' or 'personal'.
  final String tag;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
    // Defaults to 'business' if not specified.
    this.tag = 'business',
  });

  // Creates a copy of this transaction with optional new values for each property.
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
      // Include the tag property in the map for database storage.
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
      // Retrieve the tag from the map, defaulting to 'business' for legacy data.
      tag: map['tag'] ?? 'business',
    );
  }
}
