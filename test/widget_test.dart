/// Widget tests for Personal Finance Tracker application
///
/// These tests verify basic functionality and model behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/models/transaction.dart';
import 'package:personal_finance_tracker/models/category.dart';
import 'package:personal_finance_tracker/models/bill.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction model creates and serializes correctly', () {
      final transaction = Transaction(
        type: 'expense',
        amount: 100.0,
        description: 'Test transaction',
        date: '2024-01-01T00:00:00.000Z',
        categoryId: 1,
      );

      expect(transaction.type, 'expense');
      expect(transaction.amount, 100.0);
      expect(transaction.description, 'Test transaction');
      expect(transaction.categoryId, 1);

      final map = transaction.toMap();
      expect(map['type'], 'expense');
      expect(map['amount'], 100.0);
      expect(map['description'], 'Test transaction');
    });

    test('Transaction fromMap creates correct instance', () {
      final map = {
        'id': 1,
        'type': 'income',
        'amount': 200.0,
        'description': 'Salary',
        'date': '2024-01-01T00:00:00.000Z',
        'category_id': 2,
      };

      final transaction = Transaction.fromMap(map);
      expect(transaction.id, 1);
      expect(transaction.type, 'income');
      expect(transaction.amount, 200.0);
      expect(transaction.categoryId, 2);
    });
  });

  group('Category Model Tests', () {
    test('Category model creates and serializes correctly', () {
      final category = Category(
        name: 'Food',
        type: 'expense',
        iconCodePoint: 0xe8cc,
        colorValue: 0xFF4CAF50,
      );

      expect(category.name, 'Food');
      expect(category.type, 'expense');
      expect(category.iconCodePoint, 0xe8cc);
      expect(category.colorValue, 0xFF4CAF50);

      final map = category.toMap();
      expect(map['name'], 'Food');
      expect(map['type'], 'expense');
    });
  });

  group('Bill Model Tests', () {
    test('Bill model creates and serializes correctly', () {
      final bill = Bill(
        name: 'Rent',
        amount: 1000.0,
        dueDate: DateTime(2024, 1, 15),
        isRecurring: true,
        recurrenceType: 'monthly',
        recurrenceValue: 15,
      );

      expect(bill.name, 'Rent');
      expect(bill.amount, 1000.0);
      expect(bill.isRecurring, true);
      expect(bill.recurrenceType, 'monthly');
      expect(bill.recurrenceValue, 15);

      final map = bill.toMap();
      expect(map['name'], 'Rent');
      expect(map['amount'], 1000.0);
      expect(map['isRecurring'], 1);
    });
  });
}
