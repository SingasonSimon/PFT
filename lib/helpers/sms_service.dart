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
        count: 50, // Fetches the 50 most recent messages
      );

      final existingTransactions = await dbHelper.getTransactions(userId);

      for (var message in messages) {
        if (message.body == null || message.date == null) continue;

        final transactionCode = _getTransactionCode(message.body!);
        if (transactionCode == null) continue;

        final isDuplicate = existingTransactions.any((t) => t.description.contains(transactionCode));
        if (isDuplicate) continue;

        // Pass the message date to the parsing function
        _parseAndSave(message, transactionCode, userId);
      }
    }
  }

  String? _getTransactionCode(String body) {
    final codeRegex = RegExp(r'^([A-Z0-9]+)\sConfirmed\.');
    final match = codeRegex.firstMatch(body);
    return match?.group(1);
  }

  Future<void> _parseAndSave(SmsMessage message, String transactionCode, String userId) async {
    final String body = message.body!;
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
      description = 'M-Pesa Transaction';
    }
    
    description += ' ($transactionCode)';

    final newTransaction = model.Transaction(
      type: transactionType,
      amount: amount,
      description: description,
      // THE FIX: Use the actual date from the SMS message
      date: (message.date ?? DateTime.now()).toIso8601String(),
      categoryId: await _getOrCreateMpesaCategory(userId),
    );

    await dbHelper.addTransaction(newTransaction, userId);
    print("MPESA transaction ($transactionCode) automatically synced!");
  }

  // UPDATED: This now correctly specifies the category type
  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    // M-Pesa is treated as an 'expense' category for organizational purposes
    return dbHelper.getOrCreateCategory(categoryName, userId, type: 'expense');
  }
}
