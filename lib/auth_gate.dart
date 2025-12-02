/// Authentication gate widget
///
/// Manages application routing based on authentication state and passcode settings.
/// Routes users to welcome screen, passcode screen, or main screen as appropriate.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'screens/welcome_screen.dart';
import 'screens/passcode_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<bool> _isPasscodeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('passcode') != null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for auth state, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is not signed in, show the welcome screen
        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        // User is signed in, now check for passcode
        return FutureBuilder<bool>(
          future: _isPasscodeEnabled(),
          builder: (context, passcodeSnapshot) {
            // While checking for passcode, show a loading indicator
            if (passcodeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final bool passcodeEnabled = passcodeSnapshot.data ?? false;

            // If passcode is enabled, show the passcode screen for verification
            if (passcodeEnabled) {
              return const PasscodeScreen(
                isSettingPasscode: false, // We are verifying, not setting
                isAppUnlock: true, // A new flag to tell the screen it's for unlocking the app
              );
            }

            // If no passcode, go directly to the main screen
            return const MainScreen();
          },
        );
      },
    );
  }
}
