import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../models/transaction.dart' as model;
import 'transaction_detail_screen.dart'; // NEW: Import the detail screen

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final dbHelper = DatabaseHelper();
  List<model.Transaction> _allTransactions = [];
  List<model.Transaction> _filteredTransactions = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(_filterTransactions);
  }

  Future<void> _loadTransactions() async {
    if (_currentUser == null) return;
    if (mounted) setState(() => _isLoading = true);
    final transactions = await dbHelper.getTransactions(_currentUser!.uid);
    if (mounted) {
      setState(() {
        _allTransactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
        // After loading, apply any existing search query
        _filterTransactions();
      });
    }
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        final descriptionMatch = transaction.description.toLowerCase().contains(query);
        final amountMatch = transaction.amount.toString().contains(query);
        return descriptionMatch || amountMatch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using the currency symbol from the home screen would be better, but for now this is fine.
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'KSh ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by description or amount',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? const Center(child: Text('No transactions found.'))
                      : ListView.builder(
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _filteredTransactions[index];
                            final isIncome = transaction.type == 'income';
                            final amountColor = isIncome ? Colors.green : Colors.red;
                            final amountPrefix = isIncome ? '+' : '-';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: amountColor,
                                ),
                                title: Text(transaction.description.isEmpty
                                    ? transaction.type.capitalize()
                                    : transaction.description),
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
                                  '$amountPrefix${currencyFormatter.format(transaction.amount)}',
                                  style: TextStyle(
                                    color: amountColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // NEW: onTap logic to navigate to the detail screen
                                onTap: () async {
                                  // Navigate and wait for a result.
                                  final result = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => TransactionDetailScreen(transaction: transaction),
                                    ),
                                  );
                                  
                                  // If the detail screen returned 'true', it means something changed.
                                  if (result == true) {
                                    _loadTransactions(); // Refresh the list
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// Helper extension to capitalize strings
extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
