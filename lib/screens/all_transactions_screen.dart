import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final dbHelper = DatabaseHelper();
  List<model.Transaction> _allTransactions = [];
  List<model.Transaction> _filteredTransactions = [];
  List<Category> _allCategories = []; // NEW: To hold categories for the filter
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // NEW: State variables to hold the current filter values
  int? _filterCategoryId;
  String? _filterType;
  DateTimeRange? _filterDateRange;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_applyAllFilters);
  }

  Future<void> _loadInitialData() async {
    if (_currentUser == null) return;
    if (mounted) setState(() => _isLoading = true);
    
    // Load both transactions and categories
    final transactions = await dbHelper.getTransactions(_currentUser!.uid);
    final categories = await dbHelper.getCategories(_currentUser!.uid);

    if (mounted) {
      setState(() {
        _allTransactions = transactions;
        _allCategories = categories;
        _isLoading = false;
        _applyAllFilters(); // Apply initial (empty) filters
      });
    }
  }

  // UPDATED: This function now applies ALL filters, not just search
  void _applyAllFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        // Search filter
        final descriptionMatch = transaction.description.toLowerCase().contains(query);
        final amountMatch = transaction.amount.toString().contains(query);
        final searchMatch = query.isEmpty || descriptionMatch || amountMatch;

        // Category filter
        final categoryMatch = _filterCategoryId == null || transaction.categoryId == _filterCategoryId;

        // Type filter
        final typeMatch = _filterType == null || transaction.type == _filterType;

        // Date range filter
        final dateMatch = _filterDateRange == null ||
            (DateTime.parse(transaction.date).isAfter(_filterDateRange!.start) &&
             DateTime.parse(transaction.date).isBefore(_filterDateRange!.end.add(const Duration(days: 1))));

        return searchMatch && categoryMatch && typeMatch && dateMatch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // NEW: Function to show the filter bottom sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Use StatefulBuilder to manage the state within the bottom sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, left: 20, right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter Transactions', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),

                  // Filter by Type
                  DropdownButtonFormField<String>(
                    value: _filterType,
                    hint: const Text('Filter by Type'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    ],
                    onChanged: (value) => setModalState(() => _filterType = value),
                  ),
                  const SizedBox(height: 16),

                  // Filter by Category
                  DropdownButtonFormField<int>(
                    value: _filterCategoryId,
                    hint: const Text('Filter by Category'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _allCategories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name))).toList(),
                    onChanged: (value) => setModalState(() => _filterCategoryId = value),
                  ),
                  const SizedBox(height: 16),

                  // Filter by Date Range
                  ListTile(
                    title: Text(_filterDateRange == null 
                        ? 'Filter by Date' 
                        : '${DateFormat.yMd().format(_filterDateRange!.start)} - ${DateFormat.yMd().format(_filterDateRange!.end)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => _filterDateRange = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _filterCategoryId = null;
                            _filterType = null;
                            _filterDateRange = null;
                          });
                          // Also clear the main state
                          setState(() {
                             _filterCategoryId = null;
                            _filterType = null;
                            _filterDateRange = null;
                          });
                          _applyAllFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Apply the filters to the main screen's state
                          setState(() {}); 
                          _applyAllFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'KSh ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          // NEW: Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
            tooltip: 'Filter Transactions',
          ),
        ],
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? const Center(child: Text('No transactions match your filters.'))
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
                                leading: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor),
                                title: Text(transaction.description.isEmpty ? transaction.type.capitalize() : transaction.description),
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
                                  style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
                                ),
                                onTap: () async {
                                  final result = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(builder: (context) => TransactionDetailScreen(transaction: transaction)),
                                  );
                                  if (result == true) {
                                    _loadInitialData(); // Use the full reload to get fresh data
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

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

