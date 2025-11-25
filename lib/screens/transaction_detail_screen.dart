import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../helpers/dialog_helper.dart';
import '../helpers/date_picker_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import 'manage_categories_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final model.Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _transactionType;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  
  int? _selectedCategoryId;
  late Future<List<Category>> _categoriesFuture;
  bool _isUpdating = false;
  bool _isDeleting = false;

  final dbHelper = DatabaseHelper();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.transaction.type;
    _amountController = TextEditingController(text: widget.transaction.amount.toString());
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _selectedDate = DateTime.parse(widget.transaction.date);
    _selectedCategoryId = widget.transaction.categoryId;
    
    _loadCategories();
  }

  void _loadCategories() {
    final user = _currentUser;
    if (user != null) {
      setState(() {
        _categoriesFuture = dbHelper.getCategories(user.uid, type: _transactionType);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }
    
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
    final updatedTransaction = widget.transaction.copyWith(
      type: _transactionType,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text,
      date: _selectedDate.toIso8601String(),
      categoryId: _selectedCategoryId,
      );

      final user = _currentUser;
      if (user == null) return;
      await dbHelper.updateTransaction(updatedTransaction, user.uid);

      if (!mounted) return;
      
      // Reset state first
      setState(() {
        _isUpdating = false;
      });
      
      // Show success and navigate
      SnackbarHelper.showSuccess(context, 'Transaction updated successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        SnackbarHelper.showError(context, 'Failed to update transaction');
      }
    }
  }

  Future<void> _deleteTransaction() async {
    if (_currentUser == null || _isDeleting) return;

    final bool? confirm = await DialogHelper.showConfirmDialog(
      context: context,
      title: 'Confirm Deletion',
      message: 'Are you sure you want to permanently delete this transaction?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirm == true && mounted) {
      setState(() {
        _isDeleting = true;
      });

      final user = _currentUser;
      if (user == null) return;
      try {
        await dbHelper.deleteTransaction(widget.transaction.id!, user.uid);
        if (!mounted) return;
        
        // Reset state first
        setState(() {
          _isDeleting = false;
        });
        
        // Show success and navigate
        SnackbarHelper.showSuccess(context, 'Transaction deleted successfully!');
      Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          SnackbarHelper.showError(context, 'Failed to delete transaction');
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await DatePickerHelper.showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Transaction',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isUpdating ? null : _deleteTransaction,
            tooltip: 'Delete Transaction',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Transaction Type Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
          children: [
                    Expanded(
                      child: _buildTypeButton(
                        'expense',
                        'Expense',
                        Icons.arrow_upward,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        'income',
                        'Income',
                        Icons.arrow_downward,
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
            ),
              const SizedBox(height: 32),
              
              // Amount Field
              _buildSectionTitle('Amount'),
              const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
              ),
              validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                return null;
              },
            ),
              const SizedBox(height: 32),
            
              // Category Field
              _buildSectionTitle('Category'),
              const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Category>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                      }
                      
                      final categories = snapshot.data ?? [];
                        final bool isValueValid = _selectedCategoryId != null && 
                            categories.any((c) => c.id == _selectedCategoryId);
                      final int? dropdownValue = isValueValid ? _selectedCategoryId : null;
                      
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonFormField<int>(
                        value: dropdownValue,
                        decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _transactionType == 'expense'
                                      ? Icons.category
                                      : Icons.source,
                                  color: const Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            hint: Text(
                              'Select category',
                              style: TextStyle(color: Colors.grey[500]),
                        ),
                        items: categories.map((category) {
                              IconData icon = Icons.label;
                              if (category.iconCodePoint != null) {
                                icon = IconData(
                                  category.iconCodePoint!,
                                  fontFamily: 'MaterialIcons',
                                );
                              }
                          return DropdownMenuItem<int>(
                            value: category.id,
                                child: Row(
                                  children: [
                                    Icon(icon, size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          setState(() {
                            _selectedCategoryId = newValue;
                          });
                        },
                            validator: (value) =>
                                value == null ? 'Please select a category' : null,
                          ),
                      );
                    },
                  ),
                ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF4CAF50)),
                      onPressed: (_isUpdating || _isDeleting) ? null : () async {
                    await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ManageCategoriesScreen(),
                          ),
                    );
                    _loadCategories();
                  },
                      tooltip: 'Add Category',
                      iconSize: 28,
                    ),
                  ),
              ],
            ),
              const SizedBox(height: 32),

              // Description Field
              _buildSectionTitle('Description (Optional)'),
              const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Add a note or description...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
              ),
            ),
              const SizedBox(height: 32),

              // Date Field
              _buildSectionTitle('Date'),
              const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                child: TextFormField(
                  controller: TextEditingController(
                        text: DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  ),
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Update Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (_isUpdating || _isDeleting) ? null : _updateTransaction,
                  child: _isUpdating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Update Transaction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon, Color color) {
    final isSelected = _transactionType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _transactionType = type;
          _selectedCategoryId = null;
          _loadCategories();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
