// lib/helpers/sms_service.dart

import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import '../models/transaction.dart' as model;
// Import the Category model

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
    final boughtAirtimeRegex = RegExp(r"You bought Ksh[\d,]+\.\d{2} of airtime for number (\d+)");
    final payBillRegex = RegExp(r"sent to (.+?) for account");

    if (payBillRegex.hasMatch(body)) {
      final recipient = payBillRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid bill to $recipient';
      transactionType = 'expense';
    } else if (paidToRegex.hasMatch(body)) {
      final recipient = paidToRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Paid to $recipient';
      transactionType = 'expense';
    } else if (receivedFromRegex.hasMatch(body)) {
      final sender = receivedFromRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Received from $sender';
      transactionType = 'income';
    } else if (sentToRegex.hasMatch(body)) {
      final recipient = sentToRegex.firstMatch(body)!.group(1)!.trim().split(' ').first;
      description = 'Sent to $recipient';
      transactionType = 'expense';
    } else if (boughtAirtimeRegex.hasMatch(body)) {
      final number = boughtAirtimeRegex.firstMatch(body)!.group(1)!.trim();
      description = 'Bought airtime for $number';
      transactionType = 'expense';
    } else {
      description = 'M-Pesa Transaction'; // Fallback
    }
    
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

  // CORRECTED: This method now correctly uses the new function from DatabaseHelper.
  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    return dbHelper.getOrCreateCategory(categoryName, userId);
  }
}