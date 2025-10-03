// lib/helpers/sms_service.dart

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import '../models/transaction.dart' as model;

class SmsService {
  final SmsQuery _query = SmsQuery();
  final dbHelper = DatabaseHelper();
  
  Future<void> syncMpesaMessages(String userId) async {
    var permission = await Permission.sms.status;
    if (permission.isGranted) {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: 'MPESA',
        count: 50, // Check more messages on first sync
      );

      final existingTransactions = await dbHelper.getTransactions(userId);

      for (var message in messages) {
        if (message.body == null) continue;

        final transactionCode = _getTransactionCode(message.body!);
        if (transactionCode == null) continue;

        final isDuplicate = existingTransactions.any((t) => t.description.contains(transactionCode));
        if (isDuplicate) continue;

        _parseAndSave(message.body!, transactionCode, userId);
      }
    }
  }

  String? _getTransactionCode(String body) {
    final codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed\.');
    final match = codeRegex.firstMatch(body);
    return match?.group(1);
  }

  Future<void> _parseAndSave(String body, String transactionCode, String userId) async {
    double? amount;
    String transactionType = 'expense'; // Default to expense

    // Regex to find the amount (works for most messages)
    final amountRegex = RegExp(r"Ksh([\d,]+\.\d{2})");
    final amountMatch = amountRegex.firstMatch(body);

    if (amountMatch != null) {
      amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
    } else {
      return; // If no amount found, ignore message
    }

    // --- UPDATED: Check for different message types ---
    if (body.toLowerCase().contains('you have received')) {
      transactionType = 'income';
    } else if (body.toLowerCase().contains('sent to')) {
      transactionType = 'expense';
    } else if (body.toLowerCase().contains('paid to')) {
      transactionType = 'expense';
    } else if (body.toLowerCase().contains('buy goods')) {
      transactionType = 'expense';
    }
    // You can add more 'else if' conditions here for other M-Pesa formats

    final newTransaction = model.Transaction(
      type: transactionType,
      amount: amount,
      description: body, // We still save the full body for accuracy
      date: DateTime.now().toIso8601String(),
      categoryId: await _getOrCreateMpesaCategory(userId),
    );

    await dbHelper.addTransaction(newTransaction, userId);
    print("MPESA transaction ($transactionCode) automatically synced!");
  }

  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    int? categoryId = await dbHelper.getCategoryId(categoryName, userId);
    if (categoryId == null) {
      categoryId = await dbHelper.addCategory(categoryName, userId);
    }
    return categoryId;
  }
}