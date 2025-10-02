// lib/helpers/sms_service.dart

import 'package:telephony/telephony.dart';
import 'database_helper.dart';
import '../models/transaction.dart' as model;

// This function must be outside of a class
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  // This function will be called when an SMS is received in the background.
  // For now, we'll just print it. We'll add parsing logic later.
  print("Background SMS received: ${message.body}");
}

class SmsService {
  final Telephony telephony = Telephony.instance;
  final dbHelper = DatabaseHelper();

  void startListening(String userId) {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        // This is called when the app is OPEN
        _parseAndSave(message, userId);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  Future<void> _parseAndSave(SmsMessage message, String userId) async {
    // Only parse messages from MPESA
    if (message.address?.toUpperCase() == 'MPESA') {
      String? body = message.body;
      if (body == null) return;

      // Example parsing for a "Paid to" message
      // Format: "Q... Confirmed. Ksh100.00 paid to KPLC PREPAID..."
      final paidToRegex = RegExp(r"Ksh([\d,]+\.\d{2}) paid to (.+?)\. on");
      
      if (paidToRegex.hasMatch(body)) {
        final match = paidToRegex.firstMatch(body)!;
        final amountString = match.group(1)!.replaceAll(',', '');
        final recipient = match.group(2)!.trim();
        final amount = double.parse(amountString);

        // We have the data, now let's create a transaction
        final newTransaction = model.Transaction(
          type: 'expense',
          amount: amount,
          description: 'Paid to $recipient',
          date: DateTime.now().toIso8601String(),
          categoryId: await _getOrCreateMpesaCategory(userId),
        );

        await dbHelper.addTransaction(newTransaction, userId);
        print("MPESA transaction automatically saved!");
      }
    }
  }

  Future<int> _getOrCreateMpesaCategory(String userId) async {
    const categoryName = 'M-Pesa';
    int? categoryId = await dbHelper.getCategoryId(categoryName, userId);
    categoryId ??= await dbHelper.addCategory(categoryName, userId);
    return categoryId;
  }
}