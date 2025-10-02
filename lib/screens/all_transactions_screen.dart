// lib/screens/all_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import
import '../helpers/database_helper.dart';
import '../models/transaction.dart' as model;

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
  final User? _currentUser = FirebaseAuth.instance.currentUser; // Get user

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(_filterTransactions);
  }

  Future<void> _loadTransactions() async {
    if (_currentUser == null) return;
    final transactions = await dbHelper.getTransactions(_currentUser.uid);
    setState(() {
      _allTransactions = transactions;
      _filteredTransactions = transactions;
      _isLoading = false;
    });
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
                      labelText: 'Search by description or amount',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
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
                              ? transaction.type.toUpperCase()
                              : transaction.description),
                          subtitle: Text(transaction.date.split('T')[0]),
                          trailing: Text(
                            '$amountPrefix${currencyFormatter.format(transaction.amount)}',
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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