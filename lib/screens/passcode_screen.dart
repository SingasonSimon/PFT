// lib/screens/passcode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import MainScreen to navigate to it

class PasscodeScreen extends StatefulWidget {
  final bool isSettingPasscode;
  // NEW: Flag to check if we're unlocking the app on startup
  final bool isAppUnlock;

  const PasscodeScreen({
    super.key, 
    required this.isSettingPasscode,
    this.isAppUnlock = false, // Default to false for existing calls
  });

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
    final navigator = Navigator.of(context);

    // This block is for SETTING a new passcode
    if (widget.isSettingPasscode) {
      if (savedPin != null && savedPin == pin) {
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
          navigator.pop(true);
        } else {
          Fluttertoast.showToast(msg: 'Passcodes do not match. Please try again.');
          setState(() {
            _pinToConfirm = null;
            _title = 'Create a New Passcode';
            _pinController.clear();
          });
        }
      }
    } 
    // This block is for VERIFYING an existing passcode
    else {
      if (savedPin == pin) {
        // UPDATED: Check if we are unlocking the app
        if (widget.isAppUnlock) {
          // If yes, replace the current screen with the MainScreen
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          // If no (e.g., just verifying from settings), just pop back
          navigator.pop(true);
        }
      } else {
        Fluttertoast.showToast(msg: 'Incorrect Passcode');
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
        // UPDATED: Hide the back button only when unlocking the app on startup
        automaticallyImplyLeading: !widget.isAppUnlock,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 60),
              const SizedBox(height: 20),
              Text(
                _title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
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