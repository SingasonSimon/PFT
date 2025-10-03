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
        count: 50,
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

  // --- UPDATED: The parser is now much smarter and creates clean descriptions ---
  Future<void> _parseAndSave(String body, String transactionCode, String userId) async {
    String description = '';
    double? amount;
    String transactionType = 'expense';

    final amountRegex = RegExp(r"Ksh([\d,]+\.\d{2})");
    final match = amountRegex.firstMatch(body);
    if (match != null) {
      amount = double.parse(match.group(1)!.replaceAll(',', ''));
    } else {
      return;
    }

    final paidToRegex = RegExp(r"paid to (.+?)\.");
    final receivedFromRegex = RegExp(r"received Ksh[\d,]+\.\d{2} from (.+?) on");
    final sentToRegex = RegExp(r"sent to (.+?) on");

    if (paidToRegex.hasMatch(body)) {
      final recipient = paidToRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid to $recipient';
      transactionType = 'expense';
    } else if (receivedFromRegex.hasMatch(body)) {
      final sender = receivedFromRegex.firstMatch(body)!.group(1)!.trim().split(' ')[0]; // Get just the first name
      description = 'Received from $sender';
      transactionType = 'income';
    } else if (sentToRegex.hasMatch(body)) {
      final recipient = sentToRegex.firstMatch(body)!.group(1)!.trim().split(' ')[0]; // Get just the first name
      description = 'Sent to $recipient';
      transactionType = 'expense';
    } else {
      description = 'M-Pesa Transaction'; // Fallback
    }
    
    // Add the transaction code for reference and duplicate checking
    description += ' ($transactionCode)';

    final newTransaction = model.Transaction(
      type: transactionType,
      amount: amount,
      description: description,
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