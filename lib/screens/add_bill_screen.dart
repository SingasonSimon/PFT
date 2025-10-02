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

  Future<void> _saveBill() async {
    // --- THE FIX IS HERE: Add try...catch to find the error ---
    try {
      if (_formKey.currentState!.validate() && _currentUser != null) {
        final dbHelper = DatabaseHelper();
        final billName = _nameController.text.trim();

        final existingBills = await dbHelper.getBills(_currentUser.uid);
        final isDuplicate = existingBills.any((bill) => bill.name.toLowerCase() == billName.toLowerCase());

        if (isDuplicate) {
          Fluttertoast.showToast(
            msg: 'A bill with this name already exists.',
            backgroundColor: Colors.red,
          );
          return;
        }

        final newBill = Bill(
          name: billName,
          amount: double.parse(_amountController.text),
          dueDate: _selectedDate,
        );

        final newBillId = await dbHelper.addBill(newBill, _currentUser.uid);

        final billWithId = Bill(
          id: newBillId,
          name: newBill.name,
          amount: newBill.amount,
          dueDate: newBill.dueDate,
        );

        final notificationService = NotificationService();
        await notificationService.scheduleBillNotification(billWithId);

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // This will print the exact error to your Debug Console
      print('--- ERROR SAVING BILL ---');
      print(e);
      print('-------------------------');
      Fluttertoast.showToast(
        msg: 'An error occurred: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
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
              validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Please enter an amount' : null,
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveBill,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Bill'),
            ),
          ],
        ),
      ),
    );
  }
}