// lib/screens/savings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/savings.dart';
import '../models/transaction.dart' as model;

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final dbHelper = DatabaseHelper();
  late Future<List<SavingsGoal>> _savingsGoalsFuture;
  final _goalNameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _addAmountController = TextEditingController();
  final currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: 'KSh ');
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _refreshSavingsList();
  }

  void _refreshSavingsList() {
    if (_currentUser == null) return;
    setState(() {
      _savingsGoalsFuture = dbHelper.getSavingsGoals(_currentUser!.uid);
    });
  }

  void _showAddGoalDialog() {
    _goalNameController.clear();
    _targetAmountController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Savings Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _goalNameController,
              decoration: const InputDecoration(labelText: 'Goal Name'),
            ),
            TextField(
              controller: _targetAmountController,
              decoration: const InputDecoration(labelText: 'Target Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (_goalNameController.text.isNotEmpty && _targetAmountController.text.isNotEmpty && _currentUser != null) {
                final newGoal = SavingsGoal(
                  goalName: _goalNameController.text,
                  targetAmount: double.parse(_targetAmountController.text),
                );
                await dbHelper.addSavingsGoal(newGoal, _currentUser!.uid);
                Navigator.pop(context);
                _refreshSavingsList();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddFundsDialog(SavingsGoal goal) {
    _addAmountController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to "${goal.goalName}"'),
        content: TextField(
          controller: _addAmountController,
          decoration: const InputDecoration(labelText: 'Amount to Add'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (_addAmountController.text.isNotEmpty && _currentUser != null) {
                final amountToAdd = double.parse(_addAmountController.text);
                
                goal.currentAmount += amountToAdd;
                await dbHelper.updateSavingsGoal(goal);

                final savingsTransaction = model.Transaction(
                  type: 'expense',
                  amount: amountToAdd,
                  description: 'Contribution to ${goal.goalName}',
                  date: DateTime.now().toIso8601String(),
                  categoryId: await _getOrCreateSavingsCategory(),
                );
                await dbHelper.addTransaction(savingsTransaction, _currentUser!.uid);

                Navigator.pop(context);
                _refreshSavingsList();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<int> _getOrCreateSavingsCategory() async {
    if (_currentUser == null) return -1;
    const categoryName = 'Savings';
    int? categoryId = await dbHelper.getCategoryId(categoryName, _currentUser!.uid);
    if (categoryId == null) {
      categoryId = await dbHelper.addCategory(categoryName, _currentUser!.uid);
    }
    return categoryId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<SavingsGoal>>(
        future: _savingsGoalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Savings Goals Yet',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the "New Goal" button to create your first one.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }
          final goals = snapshot.data!;
          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0.0;
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(goal.goalName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          // --- THE FIX IS HERE ---
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              if (_currentUser == null) return;
                              final bool? confirm = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: Text('Are you sure you want to delete the "${goal.goalName}" savings goal?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await dbHelper.deleteSavingsGoal(goal.id!, _currentUser!.uid);
                                _refreshSavingsList();
                              }
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${currencyFormatter.format(goal.currentAmount)} / ${currencyFormatter.format(goal.targetAmount)}',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.toDouble(),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => _showAddFundsDialog(goal),
                          child: const Text('Add Funds'),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        label: const Text('New Goal'),
        icon: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}