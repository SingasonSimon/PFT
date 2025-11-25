import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../helpers/pdf_helper.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportDataFuture;
  final String _currencySymbol = 'KSh';
  final compactFormatter = NumberFormat.compact();
  final currencyFormatter = NumberFormat.currency(symbol: '', decimalDigits: 0);
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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
    final categoryMap = {for (var cat in categories) if (cat.id != null) cat.id!: cat};
    return {'transactions': transactions, 'categoryMap': categoryMap};
  }

  ({double income, double expenses, double profitLoss, String tip, Color color})
      _buildSummaryStats(List<model.Transaction> transactions, String timeFilter) {
    final periodTransactions = _filterTransactionsByPeriod(transactions, timeFilter);

    final income = periodTransactions
        .where((t) => t.type == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = periodTransactions
        .where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final profitLoss = income - expenses;

    String periodText =
        timeFilter == 'week' ? 'this week' : timeFilter == 'month' ? 'this month' : 'this year';

    String tip;
    Color color;
    if (profitLoss > 0) {
      tip = 'Great financial progress $periodText! Keep growing your buffer.';
      color = const Color(0xFF1B5E20);
    } else if (profitLoss < 0) {
      tip =
          'Spending overtook earnings $periodText. Review subscriptions and high-impact expenses.';
      color = const Color(0xFFC62828);
    } else {
      tip = 'Income and expenses balanced $periodText. Keep tracking to stay consistent.';
      color = const Color(0xFFF9A825);
    }

    return (income: income, expenses: expenses, profitLoss: profitLoss, tip: tip, color: color);
  }

  List<_CashFlowPoint> _buildCashFlowSeries(List<model.Transaction> transactions, String filter) {
    final filtered = _filterTransactionsByPeriod(transactions, filter);
    final Map<String, _CashFlowPoint> grouped = {};

    for (final tx in filtered) {
      DateTime parsed;
      try {
        parsed = DateTime.parse(tx.date);
      } catch (_) {
        continue;
      }

      late String key;
      late DateTime bucketDate;

      switch (filter) {
        case 'week':
          key = DateFormat('EEE').format(parsed);
          bucketDate = DateTime(parsed.year, parsed.month, parsed.day);
          break;
        case 'year':
          key = DateFormat('MMM').format(parsed);
          bucketDate = DateTime(parsed.year, parsed.month);
          break;
        case 'month':
        default:
          key = DateFormat('d MMM').format(parsed);
          bucketDate = DateTime(parsed.year, parsed.month, parsed.day);
          break;
      }

      final existing =
          grouped.putIfAbsent(key, () => _CashFlowPoint(label: key, bucketDate: bucketDate));
      if (tx.type == 'income') {
        existing.income += tx.amount;
      } else {
        existing.expense += tx.amount;
      }
    }

    final series = grouped.values.toList()
      ..sort((a, b) => a.bucketDate.compareTo(b.bucketDate));

    return series;
  }

  List<model.Transaction> _filterTransactionsByPeriod(
      List<model.Transaction> transactions, String filter) {
    final now = DateTime.now();
    DateTime startDate;

    switch (filter) {
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

    return transactions.where((t) {
      try {
        return DateTime.parse(t.date).isAfter(startDate.subtract(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Map<String, double> _prepareExpenseData(
      List<model.Transaction> transactions, Map<int, dynamic> categoryMap) {
    final Map<String, double> expenseData = {};
    for (var transaction in transactions.where((t) => t.type == 'expense')) {
      if (transaction.categoryId != null) {
        final category = categoryMap[transaction.categoryId];
        final categoryName = category?.name ?? 'Uncategorized';
        expenseData.update(categoryName, (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReports,
            tooltip: 'Refresh data',
          ),
        ],
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
              return _buildEmptyState();
            }

            final transactions = snapshot.data!['transactions'] as List<model.Transaction>;
            final categoryMap = snapshot.data!['categoryMap'] as Map<int, dynamic>;

            final periodTransactions = _filterTransactionsByPeriod(transactions, _selectedTimeFilter);
            final summary = _buildSummaryStats(transactions, _selectedTimeFilter);
            final barChartData = _prepareBarChartData(periodTransactions);
            final expenseData = _prepareExpenseData(periodTransactions, categoryMap);
            final cashFlowSeries = _buildCashFlowSeries(transactions, _selectedTimeFilter);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'week', label: Text('Week')),
                      ButtonSegment(value: 'month', label: Text('Month')),
                      ButtonSegment(value: 'year', label: Text('Year')),
                    ],
                    selected: {_selectedTimeFilter},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedTimeFilter = selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryHeroCard(
                        title: 'Net Income (${_selectedTimeFilter.capitalize()})',
                        value:
                            '$_currencySymbol ${NumberFormat('#,##0.##').format(summary.profitLoss)}',
                        subtitle: summary.tip,
                        accentColor: summary.color,
                      ),
                      const SizedBox(height: 20),
                      _buildStatsGrid(summary),
                      const SizedBox(height: 20),
                      _buildCashFlowCard(cashFlowSeries),
                      const SizedBox(height: 20),
                      _buildIncomeExpenseBarChart(barChartData),
                      const SizedBox(height: 20),
                      _buildExpenseBreakdown(expenseData, categoryMap),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export Detailed PDF'),
                      onPressed: () {
                        if (_currentUser != null) {
                          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          final fileName = 'PersonalFinanceTracker_Report_$dateStr.pdf';
                          // Convert categoryMap to Map<int, Category> for PDF helper
                          final Map<int, Category> pdfCategoryMap = {};
                          categoryMap.forEach((key, value) {
                            if (value is Category) {
                              pdfCategoryMap[key] = value;
                            }
                          });
                          PdfHelper.generateAndSharePdf(
                            periodTransactions,
                            _currentUser!.displayName ?? 'User',
                            fileName,
                            categoryMap: pdfCategoryMap,
                            timeFilter: _selectedTimeFilter,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_chart_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a few transactions and come back for a full financial report.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(({double income, double expenses, double profitLoss, String tip, Color color})
      summary) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatTile(
          label: 'Total Income',
          value: '$_currencySymbol ${currencyFormatter.format(summary.income)}',
          icon: Icons.arrow_downward_rounded,
          iconColor: const Color(0xFF1B5E20),
        ),
        _StatTile(
          label: 'Total Expenses',
          value: '$_currencySymbol ${currencyFormatter.format(summary.expenses)}',
          icon: Icons.arrow_upward_rounded,
          iconColor: const Color(0xFFC62828),
        ),
      ],
    );
  }

  Widget _buildCashFlowCard(List<_CashFlowPoint> series) {
    if (series.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text('Not enough activity to show cash flow.',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      );
    }

    final maxY = series
        .map((point) => point.income > point.expense ? point.income : point.expense)
        .fold<double>(0, (prev, value) => value > prev ? value : prev);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Flow Trend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track earnings vs spending over time',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedTimeFilter.capitalize(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            series.isEmpty
                ? SizedBox(
                    height: 240,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No data available for this period',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 280,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY == 0 ? 1000 : (maxY * 1.3).clamp(100, double.infinity),
                        baselineY: 0,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: series.length > 7 ? (series.length / 7).ceil().toDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= series.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    series[index].label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              interval: maxY > 0 ? (maxY / 5).clamp(100, double.infinity) : 200,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  compactFormatter.format(value),
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY > 0 ? (maxY / 5).clamp(100, double.infinity) : 200,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade400, width: 2),
                            bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                            top: BorderSide.none,
                            right: BorderSide.none,
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < series.length; i++)
                                FlSpot(i.toDouble(), series[i].income),
                            ],
                            isCurved: true,
                            color: const Color(0xFF4CAF50),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 5,
                                color: const Color(0xFF4CAF50),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF4CAF50).withOpacity(0.3),
                                  const Color(0xFF4CAF50).withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < series.length; i++)
                                FlSpot(i.toDouble(), series[i].expense),
                            ],
                            isCurved: true,
                            color: const Color(0xFFE53935),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                  FlDotCirclePainter(
                                radius: 5,
                                color: const Color(0xFFE53935),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFE53935).withOpacity(0.3),
                                  const Color(0xFFE53935).withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            if (series.isNotEmpty)
              Row(
                children: [
                  _buildLegendItem('Income', const Color(0xFF4CAF50)),
                  const SizedBox(width: 16),
                  _buildLegendItem('Expenses', const Color(0xFFE53935)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseBarChart(Map<String, double> barChartData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income vs Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Snapshot for ${_selectedTimeFilter.capitalize()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getBarChartMaxY(barChartData),
                  barGroups: [
                    _buildBarGroupData(0, barChartData['Income'] ?? 0, const Color(0xFF2E7D32)),
                    _buildBarGroupData(1, barChartData['Expenses'] ?? 0, const Color(0xFFC62828)),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            value.toInt() == 0 ? 'Income' : 'Expenses',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: (_getBarChartMaxY(barChartData) / 4).clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) => Text(
                          currencyFormatter.format(value),
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildLegendItem('Income', const Color(0xFF2E7D32)),
                const SizedBox(width: 16),
                _buildLegendItem('Expenses', const Color(0xFFC62828)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseBreakdown(
      Map<String, double> expenseData, Map<int, dynamic> categoryMap) {
    final totalExpenses = expenseData.values.fold(0.0, (sum, value) => sum + value);

    if (totalExpenses == 0) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No expense data for ${_selectedTimeFilter.capitalize()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final sortedEntries = expenseData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expense Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Top categories for ${_selectedTimeFilter.capitalize()}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Text(
                  'Total $_currencySymbol${totalExpenses.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: sortedEntries.map((entry) {
                    final percentage = (entry.value / totalExpenses) * 100;
                    return PieChartSectionData(
                      color: _getColorForCategory(entry.key),
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...sortedEntries.take(5).map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForCategory(entry.key),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$_currencySymbol${entry.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${((entry.value / totalExpenses) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getBarChartMaxY(Map<String, double> barChartData) {
    final maxValue = ([
      barChartData['Income'] ?? 0,
      barChartData['Expenses'] ?? 0,
    ]..sort()).last;
    if (maxValue == 0) return 1000;
    return (maxValue * 1.2).clamp(1000, double.infinity);
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  BarChartGroupData _buildBarGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 38,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
        ),
      ],
    );
  }

  Color _getColorForCategory(String category) {
    int hash = category.hashCode;
    return Color((hash & 0x00FFFFFF) | 0xFF000000).withOpacity(0.8);
  }
}

class _SummaryHeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _SummaryHeroCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              accentColor.withOpacity(0.15),
              accentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stacked_line_chart, color: accentColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowPoint {
  final String label;
  final DateTime bucketDate;
  double income;
  double expense;

  _CashFlowPoint({
    required this.label,
    required this.bucketDate,
    this.income = 0,
    this.expense = 0,
  });
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

