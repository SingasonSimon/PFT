// lib/screens/passcode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasscodeScreen extends StatefulWidget {
  final bool isSettingPasscode;
  const PasscodeScreen({super.key, required this.isSettingPasscode});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final _pinController = TextEditingController();
  String? _pinToConfirm;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.isSettingPasscode ? 'Create a New Passcode' : 'Enter Passcode';
  }

  void _onPinCompleted(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('passcode');

    if (widget.isSettingPasscode) {
      if (savedPin == pin) {
        Fluttertoast.showToast(msg: 'New passcode cannot be the same as the old one.');
        setState(() {
          _pinToConfirm = null;
          _title = 'Create a New Passcode';
          _pinController.clear();
        });
        return;
      }

      if (_pinToConfirm == null) {
        setState(() {
          _pinToConfirm = pin;
          _title = 'Confirm your Passcode';
          _pinController.clear();
        });
      } else {
        if (_pinToConfirm == pin) {
          await prefs.setString('passcode', pin);
          Fluttertoast.showToast(msg: 'Passcode Set Successfully');
          Navigator.of(context).pop(true);
        } else {
          Fluttertoast.showToast(msg: 'Passcodes do not match. Please try again.');
          setState(() {
            _pinToConfirm = null;
            _title = 'Create a New Passcode';
            _pinController.clear();
          });
        }
      }
    } else {
      if (savedPin == pin) {
        Navigator.of(context).pop(true);
      } else {
        Fluttertoast.showToast(msg: 'Incorrect Passcode');
        // This setState call clears the fields on failure
        setState(() {
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        automaticallyImplyLeading: !widget.isSettingPasscode,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 60),
              const SizedBox(height: 20),
              Text(_title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 30),
              PinCodeFields(
                controller: _pinController,
                length: 4,
                fieldBorderStyle: FieldBorderStyle.square,
                responsive: false,
                fieldHeight: 50.0,
                fieldWidth: 50.0,
                borderWidth: 2.0,
                activeBorderColor: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10.0),
                keyboardType: TextInputType.number,
                autoHideKeyboard: false,
                obscureText: true,
                onComplete: _onPinCompleted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}