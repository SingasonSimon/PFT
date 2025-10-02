// lib/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import
import '../helpers/database_helper.dart';
import '../helpers/pdf_helper.dart';
import '../models/transaction.dart' as model;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportDataFuture;
  final String _currencySymbol = 'KSh';
  final compactFormatter = NumberFormat.compact();
  final User? _currentUser = FirebaseAuth.instance.currentUser; // Get user

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _prepareReportData();
  }

  Future<Map<String, dynamic>> _prepareReportData() async {
    if (_currentUser == null) return {}; // Return empty if no user
    final dbHelper = DatabaseHelper();
    final transactions = await dbHelper.getTransactions(_currentUser.uid);
    final categories = await dbHelper.getCategories(_currentUser.uid);
    final categoryMap = {for (var cat in categories) cat['id'] as int: cat['name'] as String};
    return {'transactions': transactions, 'categoryMap': categoryMap};
  }

  Map<String, double> _prepareExpenseData(List<model.Transaction> transactions, Map<int, String> categoryMap) {
    final Map<String, double> expenseData = {};
    for (var transaction in transactions.where((t) => t.type == 'expense')) {
      if (transaction.categoryId != null) {
        final categoryName = categoryMap[transaction.categoryId] ?? 'Uncategorized';
        expenseData.update(
          categoryName,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }
    return expenseData;
  }

  Map<String, double> _prepareBarChartData(List<model.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;
    for (var t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }
    return {'Income': totalIncome, 'Expenses': totalExpenses};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || (snapshot.data!['transactions'] as List).isEmpty) {
            return const Center(child: Text('No data to display.'));
          }

          final allTransactions = snapshot.data!['transactions'] as List<model.Transaction>;
          final categoryMap = snapshot.data!['categoryMap'] as Map<int, String>;

          final expenseData = _prepareExpenseData(allTransactions, categoryMap);
          final barChartData = _prepareBarChartData(allTransactions);
          final totalExpenses = expenseData.values.fold(0.0, (sum, amount) => sum + amount);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const Text(
                      'Income vs. Expenses',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barGroups: [
                            _buildBarGroupData(0, barChartData['Income']!, Colors.green),
                            _buildBarGroupData(1, barChartData['Expenses']!, Colors.red),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  String text = '';
                                  if (value.toInt() == 0) text = 'Income';
                                  if (value.toInt() == 1) text = 'Expenses';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(text),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0 || value == meta.max) {
                                      return Text(compactFormatter.format(value));
                                  }
                                  if (value % (meta.max / 5) < 100) {
                                    return Text(compactFormatter.format(value));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                              left: BorderSide(color: Colors.grey.shade300, width: 2),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    if (expenseData.isNotEmpty) ...[
                      const Text(
                        'Expense Breakdown by Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: expenseData.entries.map((entry) {
                              final percentage = (entry.value / totalExpenses) * 100;
                              return PieChartSectionData(
                                color: _getColorForCategory(entry.key),
                                value: entry.value,
                                title: '${percentage.toStringAsFixed(1)}%',
                                radius: 100,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...expenseData.entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: _getColorForCategory(entry.key),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.key}: $_currencySymbol${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          )),
                    ] else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No expense data to display in chart.'),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      PdfHelper.generateAndSharePdf(allTransactions);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export as PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  BarChartGroupData _buildBarGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 40,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  Color _getColorForCategory(String category) {
    int hash = category.hashCode;
    return Color((hash & 0x00FFFFFF) | 0xFF000000).withOpacity(0.8);
  }
}