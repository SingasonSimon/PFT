// lib/screens/add_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../helpers/database_helper.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBill() async {
    try {
      if (_formKey.currentState!.validate() && _currentUser != null) {
        final dbHelper = DatabaseHelper();
        final billName = _nameController.text.trim();

        // Check for duplicate bill names
        final existingBills = await dbHelper.getBills(_currentUser!.uid);
        final isDuplicate = existingBills.any((bill) => bill.name.toLowerCase() == billName.toLowerCase());

        if (isDuplicate) {
          Fluttertoast.showToast(msg: 'A bill with this name already exists.');
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
              ? (_recurrenceType == 'weekly' ? _selectedDate.weekday : _selectedDate.day)
              : null,
        );

        final newBillId = await dbHelper.addBill(newBill, _currentUser!.uid);

        // Schedule notification for the new bill
        final notificationService = NotificationService();
        await notificationService.scheduleBillNotification(newBill.copyWith(id: newBillId));

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('--- ERROR SAVING BILL: $e ---');
      Fluttertoast.showToast(
        msg: 'An error occurred while saving the bill.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
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
      appBar: AppBar(
        title: const Text('Add a New Bill'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Bill Name (e.g., Rent, Netflix)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                 if (value == null || value.isEmpty) return 'Please enter an amount';
                 if (double.tryParse(value) == null) return 'Please enter a valid number';
                 return null;
              },
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(
                    text: DateFormat('yyyy-MM-dd').format(_selectedDate),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // NEW: UI for setting a recurring bill
            SwitchListTile(
              title: const Text('Make this a recurring bill'),
              value: _isRecurring,
              onChanged: (bool value) {
                setState(() {
                  _isRecurring = value;
                });
              },
            ),
            // NEW: Show dropdown only if the bill is recurring
            if (_isRecurring) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _recurrenceType,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Repeats Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Repeats Monthly')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _recurrenceType = newValue;
                    });
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _recurrenceType == 'weekly'
                    ? 'This bill will repeat every ${DateFormat('EEEE').format(_selectedDate)}.'
                    : 'This bill will repeat on the ${_selectedDate.day.toString()}th of every month.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveBill,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Bill', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}