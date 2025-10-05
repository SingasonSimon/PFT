// Bill model represents a bill, including recurring payment properties and due date.

class Bill {
  final int? id;
  final String name;
  final double amount;
  final DateTime dueDate;
  // Properties for handling recurring bills and their recurrence details.
  final bool isRecurring;
  final String? recurrenceType; // e.g., 'monthly', 'weekly'
  final int? recurrenceValue; // e.g., day of the month/week

  Bill({
    this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isRecurring = false, // Defaults to false
    this.recurrenceType,
    this.recurrenceValue,
  });

  // NEW: A 'copyWith' method to easily create a modified copy of a bill
  Bill copyWith({
    int? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    bool? isRecurring,
    String? recurrenceType,
    int? recurrenceValue,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceValue: recurrenceValue ?? this.recurrenceValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'isRecurring': isRecurring ? 1 : 0, // Convert bool to integer for SQLite
      'recurrenceType': recurrenceType,
      'recurrenceValue': recurrenceValue,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      dueDate: DateTime.parse(map['dueDate']),
      isRecurring: map['isRecurring'] == 1, // Convert integer back to bool
      recurrenceType: map['recurrenceType'],
      recurrenceValue: map['recurrenceValue'],
    );
  }
}
