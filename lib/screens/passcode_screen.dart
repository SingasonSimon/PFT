// lib/screens/passcode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // Import MainScreen to navigate to it
import '../helpers/dialog_helper.dart';

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

  Future<void> _handleForgotPasscode() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    
    // Check if user is authenticated
    if (user == null || user.email == null) {
      Fluttertoast.showToast(
        msg: 'Please log in to reset your passcode',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Show confirmation dialog
    final bool? confirm = await DialogHelper.showConfirmDialog(
      context: context,
      title: 'Reset Passcode',
      message: 'To reset your passcode, you need to verify your identity by entering your account password.',
      confirmText: 'Continue',
      confirmColor: const Color(0xFF4CAF50),
    );

    if (confirm != true) return;

    // Show modern password input dialog
    final passwordController = TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();
    bool isPasswordVisible = false;
    bool isVerifying = false;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: passwordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with gradient background
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.2),
                          const Color(0xFF4CAF50).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Verify Identity',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Enter your account password to reset the passcode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Password Field
                  TextFormField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    enabled: !isVerifying,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
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
                          Icons.lock_outline_rounded,
                          color: Color(0xFF4CAF50),
                          size: 20,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey[600],
                        ),
                        onPressed: isVerifying
                            ? null
                            : () {
                                setDialogState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
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
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      errorText: errorText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (errorText != null) {
                        setDialogState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                  
                  if (isVerifying) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isVerifying
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  if (!passwordFormKey.currentState!.validate()) {
                                    return;
                                  }

                                  setDialogState(() {
                                    isVerifying = true;
                                    errorText = null;
                                  });

                                  try {
                                    // Re-authenticate user with password
                                    final credential = EmailAuthProvider.credential(
                                      email: user.email!,
                                      password: passwordController.text,
                                    );
                                    await user.reauthenticateWithCredential(credential);

                                    // Clear the passcode
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove('passcode');

                                    if (context.mounted) {
                                      Navigator.of(context).pop(true);
                                      Fluttertoast.showToast(
                                        msg: 'Passcode reset successfully. Please set a new passcode.',
                                        backgroundColor: const Color(0xFF4CAF50),
                                        textColor: Colors.white,
                                      );
                                      
                                      // Navigate to set new passcode
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) => const PasscodeScreen(
                                            isSettingPasscode: true,
                                          ),
                                        ),
                                      );
                                    }
                                  } on FirebaseAuthException catch (e) {
                                    setDialogState(() {
                                      isVerifying = false;
                                    });
                                    String errorMessage = 'Verification failed';
                                    if (e.code == 'wrong-password') {
                                      errorMessage = 'Incorrect password. Please try again.';
                                      setDialogState(() {
                                        errorText = 'Incorrect password';
                                      });
                                    } else if (e.code == 'too-many-requests') {
                                      errorMessage = 'Too many attempts. Please try again later.';
                                    } else if (e.code == 'network-request-failed') {
                                      errorMessage = 'Network error. Please check your connection.';
                                    }
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(errorMessage),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isVerifying = false;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    passwordController.dispose();
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
                  
                  // Forgot passcode button
                  if (!widget.isSettingPasscode && !_hasError)
                    TextButton(
                      onPressed: _handleForgotPasscode,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Forgot your passcode?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
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