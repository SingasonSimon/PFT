// PdfHelper provides utilities for generating and sharing PDF reports from transaction data.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart' as model;

class PdfHelper {
  // Generates and shares a PDF report for the given transactions and user, using the specified file name.
  static Future<void> generateAndSharePdf(List<model.Transaction> transactions,
      String userName, String fileName) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
        ),
        header: (pw.Context context) => _buildHeader(userName),
        build: (pw.Context context) {
          return [
            _buildTransactionTable(transactions),
            pw.Divider(),
            _buildSummary(transactions),
          ];
        },
      ),
    );

    // Use the provided fileName for the generated PDF instead of a hardcoded value.
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  static pw.Widget _buildHeader(String userName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Financial Report for: $userName',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
            'Report Generated on: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(
      List<model.Transaction> transactions) {
    const tableHeaders = ['Date', 'Description', 'Type', 'Amount'];

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: transactions.map((transaction) {
        return [
          transaction.date.split('T')[0],
          transaction.description.isEmpty ? '-' : transaction.description,
          transaction.type,
          'KSh ${transaction.amount.toStringAsFixed(2)}',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.all(4),
      border: pw.TableBorder.all(),
    );
  }

  static pw.Widget _buildSummary(List<model.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }
    final balance = totalIncome - totalExpenses;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(height: 10),
          pw.Text('Total Income: KSh ${totalIncome.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Expenses: KSh ${totalExpenses.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 10),
          pw.Text('Final Balance: KSh ${balance.toStringAsFixed(2)}',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
