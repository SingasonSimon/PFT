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

class _PasscodeScreenState extends State<PasscodeScreen> with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  String? _pinToConfirm;
  late String _title;
  late String _subtitle;
  bool _hasError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _updateTitles();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _updateTitles() {
    if (widget.isSettingPasscode) {
      if (_pinToConfirm == null) {
        _title = 'Create Passcode';
        _subtitle = 'Enter a 4-digit passcode to secure your app';
      } else {
        _title = 'Confirm Passcode';
        _subtitle = 'Re-enter your passcode to confirm';
      }
    } else {
      _title = 'Enter Passcode';
      _subtitle = 'Enter your 4-digit passcode to continue';
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('passcode');
    final navigator = Navigator.of(context);

    // This block is for SETTING a new passcode
    if (widget.isSettingPasscode) {
      if (savedPin != null && savedPin == pin) {
        setState(() {
          _hasError = true;
          _pinToConfirm = null;
          _pinController.clear();
        });
        _updateTitles();
        _triggerShake();
        Fluttertoast.showToast(
          msg: 'New passcode cannot be the same as the old one.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (_pinToConfirm == null) {
        setState(() {
          _pinToConfirm = pin;
          _hasError = false;
          _pinController.clear();
        });
        _updateTitles();
      } else {
        if (_pinToConfirm == pin) {
          await prefs.setString('passcode', pin);
          Fluttertoast.showToast(
            msg: 'Passcode Set Successfully',
            backgroundColor: const Color(0xFF4CAF50),
            textColor: Colors.white,
          );
          navigator.pop(true);
        } else {
          setState(() {
            _hasError = true;
            _pinToConfirm = null;
            _pinController.clear();
          });
          _updateTitles();
          _triggerShake();
          Fluttertoast.showToast(
            msg: 'Passcodes do not match. Please try again.',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
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
        setState(() {
          _hasError = true;
          _pinController.clear();
        });
        _triggerShake();
        Fluttertoast.showToast(
          msg: 'Incorrect Passcode',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        // Reset error state after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _hasError = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isAppUnlock
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          _title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Container with gradient background
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.2),
                          const Color(0xFF4CAF50).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 60,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  // Subtitle
                  Text(
                    _subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Pin Code Fields with shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PinCodeFields(
                        controller: _pinController,
                        length: 4,
                        fieldBorderStyle: FieldBorderStyle.square,
                        responsive: false,
                        fieldHeight: 64.0,
                        fieldWidth: 64.0,
                        borderWidth: 2.5,
                        activeBorderColor: _hasError 
                            ? Colors.red 
                            : const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(16.0),
                        keyboardType: TextInputType.number,
                        autoHideKeyboard: false,
                        obscureText: true,
                        obscureCharacter: '●',
                        borderColor: _hasError 
                            ? Colors.red.shade300 
                            : Colors.grey.shade300,
                        onComplete: _onPinCompleted,
                      ),
                    ),
                  ),
                  
                  // Error indicator
                  if (_hasError) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isSettingPasscode 
                              ? 'Passcodes do not match'
                              : 'Incorrect passcode',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Helper text
                  if (!widget.isSettingPasscode && !_hasError)
                    Text(
                      'Forgot your passcode?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}