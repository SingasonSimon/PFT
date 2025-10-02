class Transaction {
  final int? id; // Can be null if the transaction is not yet saved in the DB
  final String type; // 'income' or 'expense'
  final double amount;
  final String description;
  final String date;
  final int? categoryId;

  // This is the constructor for the class
  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
  });

  // Helper method to convert our Transaction object into a Map.
  // This is needed to insert data into the SQLite database.
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

  // Helper factory to create a Transaction object from a Map.
  // This is needed when we read data from the database.
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