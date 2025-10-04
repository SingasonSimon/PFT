// lib/models/transaction.dart

class Transaction {
  final int? id; // THE FIX: This must be 'int?' for the local database
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

  // THE FIX: The fromMap constructor is also corrected
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