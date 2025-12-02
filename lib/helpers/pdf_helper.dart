/// PDF helper utility for generating and sharing PDF reports
///
/// Provides functionality to create formatted PDF documents containing
/// transaction data, summaries, and financial reports.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';

class PdfHelper {
  /// Generates and shares a PDF report for the given transactions and user
  ///
  /// Creates a formatted PDF document with transaction details, summaries,
  /// and financial analysis, then shares it using the platform's share dialog.
  static Future<void> generateAndSharePdf(
    List<model.Transaction> transactions,
    String userName,
    String fileName, {
    Map<int, Category>? categoryMap,
    String timeFilter = 'month',
  }) async {
    final pdf = pw.Document();

    // Sort transactions by date (newest first)
    final sortedTransactions = List<model.Transaction>.from(transactions)
      ..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(
            base: pw.Font.courier(),
            bold: pw.Font.courierBold(),
          ),
        ),
        header: (pw.Context context) => _buildHeader(userName, timeFilter),
        footer: (pw.Context context) => _buildFooter(context.pageNumber, context.pagesCount),
        build: (pw.Context context) {
          return [
            _buildExecutiveSummary(sortedTransactions),
            pw.SizedBox(height: 20),
            _buildCategoryBreakdown(sortedTransactions, categoryMap),
            pw.SizedBox(height: 20),
            _buildTransactionTable(sortedTransactions, categoryMap),
            pw.SizedBox(height: 20),
            _buildDetailedSummary(sortedTransactions, categoryMap),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  static pw.Widget _buildHeader(String userName, String timeFilter) {
    final now = DateTime.now();
    final periodText = timeFilter == 'week' 
        ? 'This Week' 
        : (timeFilter == 'month' ? 'This Month' : 'This Year');
    
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Personal Finance Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated for: $userName',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Period: $periodText',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                DateFormat('MMMM dd, yyyy').format(now),
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                DateFormat('hh:mm a').format(now),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(int pageNumber, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Personal Finance Tracker - Confidential Report',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'Page $pageNumber of $totalPages',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(List<model.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;
    int incomeCount = 0;
    int expenseCount = 0;

    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
        incomeCount++;
      } else {
        totalExpenses += t.amount;
        expenseCount++;
      }
    }

    final balance = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (balance / totalIncome * 100) : 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Executive Summary',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _buildSummaryCard(
                'Total Income',
                'KSh ${_formatCurrency(totalIncome)}',
                PdfColors.green700,
                0,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                'Total Expenses',
                'KSh ${_formatCurrency(totalExpenses)}',
                PdfColors.red700,
                0,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                'Net Balance',
                'KSh ${_formatCurrency(balance)}',
                balance >= 0 ? PdfColors.green700 : PdfColors.red700,
                0,
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _buildSummaryCard(
                'Savings Rate',
                '${savingsRate.toStringAsFixed(1)}%',
                savingsRate >= 20 ? PdfColors.green700 : (savingsRate >= 10 ? PdfColors.orange700 : PdfColors.red700),
                0,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                'Transactions',
                '${transactions.length}',
                PdfColors.blue700,
                0,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                'Income Count',
                '$incomeCount',
                PdfColors.green600,
                0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCard(String label, String value, PdfColor color, int icon) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color, width: 1.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCategoryBreakdown(
    List<model.Transaction> transactions,
    Map<int, Category>? categoryMap,
  ) {
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};

    for (var t in transactions) {
      String categoryName = 'Uncategorized';
      if (t.categoryId != null && categoryMap != null && categoryMap.containsKey(t.categoryId)) {
        categoryName = categoryMap[t.categoryId]!.name;
      } else if (t.categoryId == null) {
        categoryName = _generateSmartDescription(t, categoryMap);
      }

      if (t.type == 'expense') {
        expenseByCategory[categoryName] = (expenseByCategory[categoryName] ?? 0) + t.amount;
      } else {
        incomeByCategory[categoryName] = (incomeByCategory[categoryName] ?? 0) + t.amount;
      }
    }

    final expenseEntries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final incomeEntries = incomeByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Breakdown',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 12),
        if (expenseEntries.isNotEmpty) ...[
          pw.Text(
            'Top Expense Categories',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red700,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildCategoryTable(expenseEntries.take(10).toList()),
          pw.SizedBox(height: 16),
        ],
        if (incomeEntries.isNotEmpty) ...[
          pw.Text(
            'Top Income Categories',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 8),
          _buildCategoryTable(incomeEntries.take(10).toList()),
        ],
      ],
    );
  }

  static pw.Widget _buildCategoryTable(List<MapEntry<String, double>> entries) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Amount', isHeader: true, align: pw.Alignment.centerRight),
            _buildTableCell('Percentage', isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        ...entries.map((entry) {
          final total = entries.fold<double>(0, (sum, e) => sum + e.value);
          final percentage = (entry.value / total * 100);
          return pw.TableRow(
            children: [
              _buildTableCell(entry.key),
              _buildTableCell('KSh ${_formatCurrency(entry.value)}', align: pw.Alignment.centerRight),
              _buildTableCell('${percentage.toStringAsFixed(1)}%', align: pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _buildTransactionTable(
    List<model.Transaction> transactions,
    Map<int, Category>? categoryMap,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Transaction Details',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.6),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Description', isHeader: true),
                _buildTableCell('Category', isHeader: true),
                _buildTableCell('Type', isHeader: true),
                _buildTableCell('Amount', isHeader: true, align: pw.Alignment.centerRight),
              ],
            ),
            // Data rows
            ...transactions.map((transaction) {
              String categoryName = 'Uncategorized';
              if (transaction.categoryId != null && categoryMap != null && categoryMap.containsKey(transaction.categoryId)) {
                categoryName = categoryMap[transaction.categoryId]!.name;
              }

              String description = transaction.description.trim();
              if (description.isEmpty) {
                description = _generateSmartDescription(transaction, categoryMap);
              }

              final date = DateTime.parse(transaction.date);
              final dateStr = DateFormat('MMM dd, yyyy').format(date);

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: transaction.type == 'income' 
                      ? PdfColors.green50 
                      : PdfColors.red50,
                ),
                children: [
                  _buildTableCell(dateStr),
                  _buildTableCell(description),
                  _buildTableCell(categoryName),
                  _buildTableCell(
                    transaction.type == 'income' ? 'Income' : 'Expense',
                    align: pw.Alignment.center,
                  ),
                  _buildTableCell(
                    'KSh ${_formatCurrency(transaction.amount)}',
                    align: pw.Alignment.centerRight,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDetailedSummary(
    List<model.Transaction> transactions,
    Map<int, Category>? categoryMap,
  ) {
    double totalIncome = 0;
    double totalExpenses = 0;
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};

    for (var t in transactions) {
      String categoryName = 'Uncategorized';
      if (t.categoryId != null && categoryMap != null && categoryMap.containsKey(t.categoryId)) {
        categoryName = categoryMap[t.categoryId]!.name;
      }

      if (t.type == 'income') {
        totalIncome += t.amount;
        incomeByCategory[categoryName] = (incomeByCategory[categoryName] ?? 0) + t.amount;
      } else {
        totalExpenses += t.amount;
        expenseByCategory[categoryName] = (expenseByCategory[categoryName] ?? 0) + t.amount;
      }
    }

    final balance = totalIncome - totalExpenses;
    final avgTransaction = transactions.isNotEmpty 
        ? (totalIncome + totalExpenses) / transactions.length 
        : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow('Total Income:', 'KSh ${_formatCurrency(totalIncome)}', PdfColors.green700),
                  _buildSummaryRow('Total Expenses:', 'KSh ${_formatCurrency(totalExpenses)}', PdfColors.red700),
                  _buildSummaryRow('Net Balance:', 'KSh ${_formatCurrency(balance)}', 
                      balance >= 0 ? PdfColors.green700 : PdfColors.red700),
                  _buildSummaryRow('Avg Transaction:', 'KSh ${_formatCurrency(avgTransaction)}', PdfColors.grey700),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow('Total Transactions:', '${transactions.length}', PdfColors.blue700),
                  _buildSummaryRow('Income Transactions:', '${transactions.where((t) => t.type == 'income').length}', PdfColors.green600),
                  _buildSummaryRow('Expense Transactions:', '${transactions.where((t) => t.type == 'expense').length}', PdfColors.red600),
                  _buildSummaryRow('Categories Used:', '${expenseByCategory.length + incomeByCategory.length}', PdfColors.purple700),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Generate smart description when description is empty
  static String _generateSmartDescription(model.Transaction transaction, Map<int, Category>? categoryMap) {
    String categoryName = 'Transaction';
    
    if (transaction.categoryId != null && categoryMap != null && categoryMap.containsKey(transaction.categoryId)) {
      categoryName = categoryMap[transaction.categoryId]!.name;
    }

    final date = DateTime.parse(transaction.date);
    final dayOfWeek = DateFormat('EEEE').format(date);
    final isWeekend = date.weekday == 6 || date.weekday == 7;
    
    String context = '';
    if (transaction.type == 'income') {
      final timeOfDay = date.hour;
      if (timeOfDay < 12) {
        context = 'Morning';
      } else if (timeOfDay < 17) {
        context = 'Afternoon';
      } else {
        context = 'Evening';
      }
      
      return '$categoryName - $context income on $dayOfWeek';
    } else {
      // Expense descriptions
      if (isWeekend) {
        return '$categoryName - Weekend expense';
      } else {
        final amount = transaction.amount;
        if (amount > 10000) {
          return '$categoryName - Major expense';
        } else if (amount > 5000) {
          return '$categoryName - Significant expense';
        } else {
          return '$categoryName - Regular expense';
        }
      }
    }
  }

  static String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}
