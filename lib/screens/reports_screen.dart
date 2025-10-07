import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../helpers/pdf_helper.dart';
import '../models/category.dart';
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
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _selectedTagFilter = 'business';
  String _selectedTimeFilter = 'month';

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _prepareReportData();
  }

  void _refreshReports() {
    setState(() {
      _reportDataFuture = _prepareReportData();
    });
  }

  Future<Map<String, dynamic>> _prepareReportData() async {
    if (_currentUser == null) return {};
    final dbHelper = DatabaseHelper();
    final transactions = await dbHelper.getTransactions(_currentUser!.uid);
    final categories = await dbHelper.getCategories(_currentUser!.uid);
    final categoryMap = {for (var cat in categories) cat.id!: cat.name};
    return {'transactions': transactions, 'categoryMap': categoryMap};
  }

  ({double profitLoss, String tip, Color color}) _getProfitLossAndTip(List<model.Transaction> transactions, String timeFilter) {
    final businessTransactions = transactions.where((t) => t.tag == 'business' || t.type == 'income').toList();
    
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (timeFilter) {
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'month':
      default:
        startDate = DateTime(now.year, now.month, 1);
        break;
    }

    final periodTransactions = businessTransactions.where((t) {
      try {
        return DateTime.parse(t.date).isAfter(startDate);
      } catch (e) {
        return false;
      }
    }).toList();

    double income = periodTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    double expenses = periodTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    double profitLoss = income - expenses;
    
    String periodText = timeFilter == 'week' ? 'this week' : (timeFilter == 'month' ? 'this month' : 'this year');

    if (profitLoss > 0) {
      return (profitLoss: profitLoss, tip: 'Great business performance $periodText!', color: Colors.green);
    } else if (profitLoss < 0) {
      return (profitLoss: profitLoss, tip: 'Your business is at a loss $periodText. Review expenses.', color: Colors.red);
    } else {
      return (profitLoss: 0, tip: 'Your business has broken even $periodText.', color: Colors.orange);
    }
  }
  
  Map<String, double> _prepareTagBreakdownData(List<model.Transaction> transactions) {
    final Map<String, double> tagData = {'Business': 0.0, 'Personal': 0.0};
    for (var transaction in transactions.where((t) => t.type == 'expense')) {
      if (transaction.tag == 'business') {
        tagData.update('Business', (value) => value + transaction.amount);
      } else if (transaction.tag == 'personal') {
        tagData.update('Personal', (value) => value + transaction.amount);
      }
    }
    return tagData;
  }

  Map<String, double> _prepareExpenseData(List<model.Transaction> transactions, Map<int, String> categoryMap) {
    final Map<String, double> expenseData = {};
    for (var transaction in transactions.where((t) => t.type == 'expense')) {
      if (transaction.categoryId != null) {
        final categoryName = categoryMap[transaction.categoryId] ?? 'Uncategorized';
        expenseData.update(categoryName, (value) => value + transaction.amount, ifAbsent: () => transaction.amount);
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
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshReports, tooltip: 'Refresh Data')],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
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

            DateTime now = DateTime.now();
            DateTime startDate;
            switch (_selectedTimeFilter) {
              case 'week':
                startDate = now.subtract(Duration(days: now.weekday - 1));
                startDate = DateTime(startDate.year, startDate.month, startDate.day);
                break;
              case 'year':
                startDate = DateTime(now.year, 1, 1);
                break;
              case 'month':
              default:
                startDate = DateTime(now.year, now.month, 1);
                break;
            }

            final timeFilteredTransactions = allTransactions.where((t) {
              try { return DateTime.parse(t.date).isAfter(startDate); } catch (e) { return false; }
            }).toList();

            final fullyFilteredTransactions = timeFilteredTransactions.where((t) {
              if (_selectedTagFilter == 'all') return true;
              if (t.type == 'income') return true;
              return t.tag == _selectedTagFilter;
            }).toList();

            final expenseData = _prepareExpenseData(fullyFilteredTransactions, categoryMap);
            final barChartData = _prepareBarChartData(fullyFilteredTransactions);
            final totalExpenses = expenseData.values.fold(0.0, (sum, amount) => sum + amount);
            final profitLossData = _getProfitLossAndTip(allTransactions, _selectedTimeFilter);
            final tagBreakdownData = _prepareTagBreakdownData(timeFilteredTransactions);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'week', label: Text('Week')),
                            ButtonSegment(value: 'month', label: Text('Month')),
                            ButtonSegment(value: 'year', label: Text('Year')),
                          ],
                          selected: {_selectedTimeFilter},
                          onSelectionChanged: (newSelection) => setState(() => _selectedTimeFilter = newSelection.first),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All Expenses')),
                      ButtonSegment(value: 'business', label: Text('Business')),
                      ButtonSegment(value: 'personal', label: Text('Personal')),
                    ],
                    selected: {_selectedTagFilter},
                    onSelectionChanged: (newSelection) => setState(() => _selectedTagFilter = newSelection.first),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Card(
                        color: profitLossData.color.withOpacity(0.15),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(children: [
                            Text('Business Profit/Loss (${_selectedTimeFilter.capitalize()})', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              '$_currencySymbol ${NumberFormat.currency(locale: 'en_US', symbol: '').format(profitLossData.profitLoss)}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: profitLossData.color),
                            ),
                            const SizedBox(height: 12),
                            Text(profitLossData.tip, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Income vs. Expenses (${_selectedTimeFilter.capitalize()}, ${_selectedTagFilter.capitalize()})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 250, 
                        child: BarChart(
                           BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: [
                              _buildBarGroupData(0, barChartData['Income'] ?? 0, Colors.green),
                              _buildBarGroupData(1, barChartData['Expenses'] ?? 0, Colors.red),
                            ],
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    String text = '';
                                    if (value.toInt() == 0) text = 'Income';
                                    if (value.toInt() == 1) text = 'Expenses';
                                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0 || value == meta.max) return Text(compactFormatter.format(value));
                                    if (meta.max > 5 && value % (meta.max / 5) < 100 && value != 0) return Text(compactFormatter.format(value));
                                    return const Text('');
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2), left: BorderSide(color: Colors.grey.shade300, width: 2))),
                            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                          ),
                        )
                      ),
                      const SizedBox(height: 40),
                      
                      if (tagBreakdownData['Business']! > 0 || tagBreakdownData['Personal']! > 0) ...[
                        Text('Business vs. Personal (${_selectedTimeFilter.capitalize()})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200, 
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              sections: [
                                if (tagBreakdownData['Business']! > 0)
                                  PieChartSectionData(value: tagBreakdownData['Business'], title: 'Business', color: Colors.blue, radius: 80),
                                if (tagBreakdownData['Personal']! > 0)
                                  PieChartSectionData(value: tagBreakdownData['Personal'], title: 'Personal', color: Colors.purple, radius: 80),
                              ],
                            ),
                          )
                        ),
                        const SizedBox(height: 40),
                      ],
                      
                      if (expenseData.isNotEmpty) ...[
                        Text('Expense Breakdown (${_selectedTimeFilter.capitalize()}, ${_selectedTagFilter.capitalize()})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }).toList(),
                            ),
                          )
                        ),
                        const SizedBox(height: 24),
                        ...expenseData.entries.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(children: [
                                Container(width: 16, height: 16, color: _getColorForCategory(entry.key)),
                                const SizedBox(width: 8),
                                Text('${entry.key}: $_currencySymbol${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                              ]),
                            )),
                      ] else
                        Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('No ${_selectedTagFilter} expense data for this period.'))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_currentUser != null) {
                          final filterName = _selectedTagFilter.capitalize();
                          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          final fileName = 'PatoTrack_${filterName}_Report_$dateStr.pdf';

                          PdfHelper.generateAndSharePdf(fullyFilteredTransactions, _currentUser!.displayName ?? 'User', fileName);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text('Export "${_selectedTagFilter.capitalize()}" Report'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // RESTORED: Full implementation of _buildBarGroupData
  BarChartGroupData _buildBarGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 40,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
        ),
      ],
    );
  }

  // RESTORED: Full implementation of _getColorForCategory
  Color _getColorForCategory(String category) {
    int hash = category.hashCode;
    return Color((hash & 0x00FFFFFF) | 0xFF000000).withOpacity(0.8);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

