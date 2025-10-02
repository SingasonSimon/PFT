// lib/helpers/pdf_helper.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart' as model;

class PdfHelper {
  static Future<void> generateAndSharePdf(List<model.Transaction> transactions) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            _buildTransactionTable(transactions),
            pw.Divider(),
            _buildSummary(transactions),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'financial_report.pdf');
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('LedgerLite App', style: const pw.TextStyle(fontSize: 16)),
        pw.Text('Report Generated: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(List<model.Transaction> transactions) {
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
          pw.Text('Total Income: KSh ${totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Expenses: KSh ${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 10),
          pw.Text('Final Balance: KSh ${balance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}