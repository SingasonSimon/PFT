// lib/models/bill.dart

class Bill {
  final int? id;
  final String name;
  final double amount;
  final DateTime dueDate;

  Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      dueDate: DateTime.parse(map['dueDate']),
    );
  }
}