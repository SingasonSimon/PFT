// lib/models/savings.dart

class SavingsGoal {
  final int? id;
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

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      goalName: map['goalName'],
      targetAmount: map['targetAmount'],
      currentAmount: map['currentAmount'],
    );
  }
}