// lib/models/savings.dart

class SavingsGoal {
  final int? id; // THE FIX: This must be 'int?' for the local database
  final String goalName;
  final double targetAmount;
  double currentAmount;

  SavingsGoal({
    this.id,
    required this.goalName,
    required this.targetAmount,
    this.currentAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalName': goalName,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
    };
  }

  // THE FIX: The fromMap constructor is also corrected
  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      goalName: map['goalName'],
      targetAmount: map['targetAmount'],
      currentAmount: map['currentAmount'],
    );
  }
}