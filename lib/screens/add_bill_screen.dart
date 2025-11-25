// lib/screens/add_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../helpers/dialog_helper.dart';
import '../helpers/date_picker_helper.dart';
import '../helpers/notification_service.dart';
import '../models/bill.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  // NEW: State variables for recurring bills
  bool _isRecurring = false;
  String _recurrenceType = 'monthly'; // Default recurrence type
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
        final dbHelper = DatabaseHelper();
        final billName = _nameController.text.trim();

        // Check for duplicate bill names
        final existingBills = await dbHelper.getBills(_currentUser.uid);
      final isDuplicate = existingBills.any(
          (bill) => bill.name.toLowerCase() == billName.toLowerCase());

        if (isDuplicate) {
        if (mounted) {
          SnackbarHelper.showError(
              context, 'A bill with this name already exists.');
          setState(() {
            _isSaving = false;
          });
        }
          return;
        }

        // UPDATED: Create a Bill object with the new recurring properties
        final newBill = Bill(
          name: billName,
          amount: double.parse(_amountController.text),
          dueDate: _selectedDate,
          isRecurring: _isRecurring,
          recurrenceType: _isRecurring ? _recurrenceType : null,
          recurrenceValue: _isRecurring
            ? (_recurrenceType == 'weekly'
                ? _selectedDate.weekday
                : _selectedDate.day)
              : null,
        );

        final newBillId = await dbHelper.addBill(newBill, _currentUser.uid);

        // Schedule notification for the new bill
        final notificationService = NotificationService();
      await notificationService
          .scheduleBillNotification(newBill.copyWith(id: newBillId));

      if (!mounted) return;
      
      // Reset state first
      setState(() {
        _isSaving = false;
      });
      
      // Show success and navigate
      SnackbarHelper.showSuccess(context, 'Bill saved successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('--- ERROR SAVING BILL: $e ---');
        if (mounted) {
        setState(() {
          _isSaving = false;
        });
        SnackbarHelper.showError(
            context, 'An error occurred while saving the bill.');
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await DatePickerHelper.showModernDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
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
          'Add Bill',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.all(24.0),
          children: [
              // Bill Name Field
              _buildSectionTitle('Bill Name'),
              const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g., Rent, Netflix, Electricity',
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a name' : null,
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
              
              // Due Date Field
              _buildSectionTitle('Due Date'),
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
              const SizedBox(height: 32),

              // Recurring Bill Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.repeat,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recurring Bill',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _isRecurring
                                ? (_recurrenceType == 'weekly'
                                    ? 'Repeats every ${DateFormat('EEEE').format(_selectedDate)}'
                                    : 'Repeats on ${_selectedDate.day}th of each month')
                                : 'One-time bill',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    Switch(
              value: _isRecurring,
              onChanged: (bool value) {
                setState(() {
                  _isRecurring = value;
                });
              },
                      activeColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
              ),
              
              // Frequency selector (only if recurring)
            if (_isRecurring) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Frequency'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _recurrenceType,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
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
                ),
                items: const [
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _recurrenceType = newValue;
                    });
                  }
                },
                ),
              ),
            ],

              const SizedBox(height: 40),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBill,
              style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                ),
                    elevation: 0,
              ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Bill',
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
}