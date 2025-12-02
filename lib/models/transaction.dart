/// Transaction model representing a financial transaction
///
/// Includes transaction type (income/expense), amount, description,
/// date, and optional category association.

class Transaction {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final int? categoryId;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
  });

  // Creates a copy of this transaction with optional new values for each property.
  Transaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? description,
    String? date,
    int? categoryId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
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
    );
  }
}
