import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../helpers/sms_service.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'add_bill_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbHelper = DatabaseHelper();
  final SmsService _smsService = SmsService();
  List<model.Transaction> _transactions = [];
  List<Bill> _bills = [];
  bool _isLoading = true;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  double _balance = 0.0;
  String _currencySymbol = 'KSh';

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initHome();
  }

  Future<void> _initHome() async {
    await _requestSmsPermission();
    if (!mounted) return;
    if (_currentUser != null) {
      _smsService.syncMpesaMessages(_currentUser!.uid).then((_) {
        if (mounted) {
          _refreshData();
        }
      });
      _refreshData();
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestSmsPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      await Permission.sms.request();
    }
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
  
  Future<void> _refreshData() async {
    if (!mounted) return;
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadCurrencyPreference(),
        _loadBills(_currentUser!.uid),
        _loadTransactions(_currentUser!.uid),
      ]);
    } catch (e) {
      print("Error refreshing data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadCurrencyPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currencySymbol = prefs.getString('currency') ?? 'KSh';
      });
    }
  }

  void _calculateSummary(List<model.Transaction> transactions) {
    _totalIncome = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    _totalExpenses = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    _balance = _totalIncome - _totalExpenses;
  }

  Future<void> _loadTransactions(String userId) async {
    final allTransactions = await dbHelper.getTransactions(userId);
    if(mounted) {
      _calculateSummary(allTransactions);
      setState(() {
        _transactions = allTransactions;
      });
    }
  }

  Future<void> _loadBills(String userId) async {
    final bills = await dbHelper.getBills(userId);
    if (mounted) {
      setState(() {
        _bills = bills;
      });
    }
  }

  Future<void> _deleteTransaction(int id, String userId) async {
    await dbHelper.deleteTransaction(id, userId);
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Deleted')),
      );
    }
    _refreshData();
  }
  
  ({IconData icon, Color color}) _getBillStyling(String billName) {
    final name = billName.toLowerCase();
    if (name.contains('rent')) return (icon: Icons.house_outlined, color: Colors.orange);
    if (name.contains('netflix') || name.contains('movie')) return (icon: Icons.movie_outlined, color: Colors.red);
    if (name.contains('wifi') || name.contains('internet')) return (icon: Icons.wifi, color: Colors.blue);
    if (name.contains('electricity') || name.contains('power')) return (icon: Icons.lightbulb_outline, color: Colors.yellow.shade700);
    if (name.contains('water')) return (icon: Icons.water_drop_outlined, color: Colors.lightBlue);
    if (name.contains('loan') || name.contains('debt')) return (icon: Icons.credit_card_outlined, color: Colors.purple);
    return (icon: Icons.receipt_long_outlined, color: Colors.grey);
  }

  ({String text, Color color}) _getBillStatus(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysLeft = dueDay.difference(today).inDays;

    if (daysLeft < 0) {
      return (text: 'Overdue', color: Colors.red);
    } else if (daysLeft == 0) {
      return (text: 'Due Today', color: Colors.orange);
    } else if (daysLeft <= 7) {
      return (text: 'Due in $daysLeft days', color: Colors.yellow.shade800);
    } else {
      return (text: '$daysLeft days left', color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7));
    }
  }
  
  DateTime _calculateNextDueDate(Bill bill) {
    if (bill.recurrenceType == 'monthly') {
      return DateTime(bill.dueDate.year, bill.dueDate.month + 1, bill.dueDate.day);
    } else if (bill.recurrenceType == 'weekly') {
      return bill.dueDate.add(const Duration(days: 7));
    }
    return bill.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;

        return Scaffold(
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getGreeting()} 👋',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                currentUser?.displayName ?? 'User',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    SummaryCard(title: 'Total Income', amount: _totalIncome, icon: Icons.trending_up, color: Colors.green, currencySymbol: _currencySymbol),
                                    SummaryCard(title: 'Total Expenses', amount: _totalExpenses, icon: Icons.trending_down, color: Colors.red, currencySymbol: _currencySymbol),
                                    SummaryCard(title: 'Balance', amount: _balance, icon: Icons.account_balance, color: _balance >= 0 ? Colors.blue : Colors.orange, currencySymbol: _currencySymbol),
                                  ],
                                ),
                              ),
                              _buildUpcomingBillsSection(currentUser),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        TextButton(
                                          onPressed: () {
                                            if (currentUser == null) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const AllTransactionsScreen()),
                                            ).then((_) => _refreshData());
                                          },
                                          child: const Text('See All'),
                                        )
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Swipe left to delete, or right to edit',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildTransactionList(currentUser),
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
              );
              if (currentUser != null) {
                _refreshData();
              }
            },
            label: const Text('Add Transaction'),
            icon: const Icon(Icons.add),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingBillsSection(User? currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upcoming Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBillScreen()))
                .then((_) {
                  if (currentUser != null) {
                    _refreshData();
                  }
                });
              }, child: const Text('Add Bill')),
            ],
          ),
        ),
        _bills.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Center(child: Text('No upcoming bills.')),
              )
            : SizedBox(
                height: 165,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final styling = _getBillStyling(bill.name);
                    final status = _getBillStatus(bill.dueDate);

                    return SizedBox(
                      width: 170,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: status.color.withOpacity(0.5), width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(styling.icon, size: 28, color: styling.color),
                                  const Spacer(),
                                  if (bill.isRecurring) Icon(Icons.sync, size: 16, color: Colors.grey.shade600)
                                ],
                              ),
                              const Spacer(),
                              Text(bill.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              Text('$_currencySymbol${bill.amount.toStringAsFixed(0)}'),
                              Text(
                                status.text,
                                style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Pay Bill'),
                                  onPressed: () async {
                                    if (currentUser == null) return;
                                    
                                    final billTransaction = model.Transaction(
                                      type: 'expense', 
                                      amount: bill.amount, 
                                      description: 'Paid bill: ${bill.name}', 
                                      date: DateTime.now().toIso8601String(), 
                                      categoryId: await dbHelper.getOrCreateCategory('Bills', currentUser.uid, type: 'expense'),
                                    );
                                    await dbHelper.addTransaction(billTransaction, currentUser.uid);

                                    if (bill.isRecurring) {
                                      final nextDueDate = _calculateNextDueDate(bill);
                                      final updatedBill = bill.copyWith(dueDate: nextDueDate);
                                      await dbHelper.updateBill(updatedBill, currentUser.uid);
                                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recurring bill "${bill.name}" paid. Next due date set.')));
                                    } else {
                                      await dbHelper.deleteBill(bill.id!, currentUser.uid);
                                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bill "${bill.name}" marked as paid.')));
                                    }
                                    
                                    _refreshData();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildTransactionList(User? currentUser) {
    if (_transactions.isEmpty) {
      return const Center(heightFactor: 5, child: Text('No transactions yet. Add one!'));
    }
    
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '');
    final recentTransactions = _transactions.take(10).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        final transaction = recentTransactions[index];
        final isIncome = transaction.type == 'income';
        final amountColor = isIncome ? Colors.green : Colors.red;
        final amountPrefix = isIncome ? '+' : '-';
        
        final isMpesa = RegExp(r'\([A-Z0-9]{10}\)').hasMatch(transaction.description);

        return Dismissible(
          key: ValueKey(transaction.id),
          
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) { // Swipe right for edit
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (context) => TransactionDetailScreen(transaction: transaction)),
              );
              if (result == true) {
                _refreshData();
              }
              return false; // Do not dismiss the item after swiping right
            } else { // Swipe left for delete
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Deletion'), content: const Text('Are you sure you want to delete this transaction?'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  );
                },
              );
            }
          },

          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart && currentUser != null) {
              _deleteTransaction(transaction.id!, currentUser.uid);
            }
          },
          
          // CORRECTED: The background (for swipe right-to-left) is now the blue edit
          background: Container(
            color: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          
          // CORRECTED: The secondaryBackground (for swipe left-to-right) is now the red delete
          secondaryBackground: Container(
            color: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              leading: isMpesa 
                ? Image.asset('assets/mpesa_logo.png', width: 40, height: 40)
                : Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor),
              title: Text(
                transaction.description.isNotEmpty ? transaction.description : transaction.type.capitalize(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Icon(
                    transaction.tag == 'business' ? Icons.business_center : Icons.person,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${transaction.tag.capitalize()} · ${transaction.date.split('T')[0]}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              trailing: Text(
                '$amountPrefix$_currencySymbol ${currencyFormatter.format(transaction.amount)}',
                style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String currencySymbol;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(title),
        trailing: Text(
          '$currencySymbol ${currencyFormatter.format(amount)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

