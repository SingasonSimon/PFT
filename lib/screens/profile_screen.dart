import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../helpers/config.dart';
import '../helpers/database_helper.dart';
import '../helpers/dialog_helper.dart';
import 'passcode_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final dbHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  final _nameController = TextEditingController();

  User? get currentUser => _auth.currentUser;

  bool _isLoggingOut = false;
  bool _isUploading = false;
  bool _isRestoring = false;
  String _selectedCurrency = 'KSh';
  bool _isPasscodeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);

    if (image == null || currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final stringToSign =
          'timestamp=$timestamp${AppConfig.cloudinaryApiSecret}';
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      request.fields['api_key'] = AppConfig.cloudinaryApiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData);
        final imageUrl = responseJson['secure_url'];

        // Update photo URL in Firebase Auth
        await currentUser!.updatePhotoURL(imageUrl);
        
        // Reload user to get updated photo URL from Firebase
        await currentUser!.reload();
        
        // Get the fresh user instance after reload
        final updatedUser = _auth.currentUser;
        
        // Verify the photo URL was saved
        if (updatedUser?.photoURL == imageUrl) {
          if (mounted) {
            setState(() {}); // Refresh UI to show new image
            SnackbarHelper.showSuccess(context, 'Profile picture updated!');
          }
        } else {
          if (mounted) {
            SnackbarHelper.showError(context, 'Profile picture updated but may not persist. Please restart the app.');
          }
        }
      } else {
        final errorData = await response.stream.bytesToString();
        debugPrint('Cloudinary Error: $errorData');
        if (mounted) {
          SnackbarHelper.showError(
              context, 'Failed to upload image. Status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to upload image: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedCurrency = prefs.getString('currency') ?? 'KSh';
        _isPasscodeEnabled = prefs.getString('passcode') != null;
      });
    }
  }

  Future<void> _saveCurrencyPreference(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    setState(() => _selectedCurrency = currency);
  }

  void _showUpdateNameDialog() async {
    final result = await DialogHelper.showInputDialog(
      context: context,
      title: 'Update Your Name',
      hintText: 'Enter your full name',
      initialValue: currentUser?.displayName,
      confirmText: 'Update',
    );
    
    if (result != null && result.isNotEmpty && currentUser != null) {
      try {
        await currentUser!.updateDisplayName(result.trim());
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Name updated successfully!');
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Failed to update name');
        }
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    if (currentUser?.email == null) return;
    try {
      await _auth.sendPasswordResetEmail(email: currentUser!.email!);
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Password reset link sent to your email.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
            context, e.message ?? 'Failed to send reset email.');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await DialogHelper.showConfirmDialog(
      context: context,
      title: 'Delete Account',
      message:
          'This is irreversible. All your data will be permanently deleted. Are you sure?',
      confirmText: 'DELETE',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      try {
        await currentUser?.delete();
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Account deleted successfully.');
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          SnackbarHelper.showError(
              context, e.message ?? 'Failed to delete account.');
        }
      }
    }
  }

  Future<void> _logout() async {
    final bool? confirm = await DialogHelper.showConfirmDialog(
      context: context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out?',
      confirmText: 'Logout',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      setState(() => _isLoggingOut = true);
      try {
        await _auth.signOut();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoggingOut = false);
          SnackbarHelper.showError(context, 'Failed to log out');
        }
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    const phoneNumber = '+254713561800'; // WhatsApp format: no spaces
    const message = 'Hello, I have a question about the Personal Finance Tracker app.';
    final whatsappUrl = Uri.parse(
        "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        SnackbarHelper.showError(
            context, 'Could not launch WhatsApp. Is it installed?');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'An error occurred.');
    }
  }

  void _showFaqDialog() {
    DialogHelper.showModernDialog(
      context: context,
      title: 'Frequently Asked Questions',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFaqItem(
              'How do I add a transaction?',
              'Tap the "+" button on the home screen, fill in the details, and tap "Save Transaction".',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              'How do I manage categories?',
              'Go to Add Transaction screen, tap the settings icon next to Category, or go to Settings > Manage Categories.',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              'Can I set up recurring bills?',
              'Yes! When adding a bill, toggle "Recurring Bill" and select the frequency (weekly or monthly).',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              'How do I view my financial reports?',
              'Tap the "Reports" tab at the bottom to see charts and breakdowns of your income and expenses.',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              'Is my data backed up?',
              'Yes! Your data is automatically synced to the cloud. You can restore it anytime from Settings.',
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              'How do I change my currency?',
              'Go to Settings > Currency and select your preferred currency from the dropdown.',
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          answer,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _handleRestore() async {
    if (currentUser == null) return;

    final bool? confirm = await DialogHelper.showConfirmDialog(
      context: context,
      title: 'Restore from Cloud',
      message:
          'This will replace all local data with your cloud backup. Are you sure?',
      confirmText: 'Restore',
      confirmColor: Colors.blue,
    );

    if (confirm == true && mounted) {
      setState(() => _isRestoring = true);
      try {
        await dbHelper.restoreFromFirestore(currentUser!.uid);
        SnackbarHelper.showSuccess(
            context,
            "Data restored successfully! Please restart the app to see all changes.");
      } catch (e) {
        SnackbarHelper.showError(context, "Error restoring data: $e");
      } finally {
        if (mounted) setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Profile Header
            if (currentUser != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.1),
                      const Color(0xFF4CAF50).withOpacity(0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                            backgroundImage: (currentUser!.photoURL != null)
                                ? NetworkImage(currentUser!.photoURL!)
                                : null,
                            child: (currentUser!.photoURL == null)
                                ? const Icon(Icons.person, size: 50, color: Color(0xFF4CAF50))
                                : null,
                          ),
                          if (_isUploading)
                            const CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF4CAF50),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            currentUser!.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showUpdateNameDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUser!.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            
            // Settings List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // App Settings Section
                  _buildSectionHeader('App Settings'),
                  const SizedBox(height: 12),
                  _buildModernCard(
                    children: [
                      _buildSettingTile(
                        icon: Icons.lock_outline,
                        title: 'Passcode Lock',
                        trailing: Switch(
                          value: _isPasscodeEnabled,
                          activeColor: const Color(0xFF4CAF50),
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            if (value) {
                              final success = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PasscodeScreen(isSettingPasscode: true)));
                              if (success == true) {
                                setState(() => _isPasscodeEnabled = true);
                              }
                            } else {
                              final success = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                      builder: (context) => const PasscodeScreen(
                                          isSettingPasscode: false)));
                              if (success == true) {
                                await prefs.remove('passcode');
                                setState(() => _isPasscodeEnabled = false);
                              }
                            }
                          },
                        ),
                      ),
                      if (_isPasscodeEnabled) ...[
                        const Divider(height: 1),
                        _buildSettingTile(
                          icon: Icons.phonelink_lock,
                          title: 'Change Passcode',
                          onTap: () async {
                            final verified = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PasscodeScreen(isSettingPasscode: false)));
                            if (verified == true) {
                              await Navigator.of(context).push<bool>(MaterialPageRoute(
                                  builder: (context) =>
                                      const PasscodeScreen(isSettingPasscode: true)));
                            }
                          },
                        ),
                      ],
                      const Divider(height: 1),
                      _buildSettingTile(
                        icon: Icons.money,
                        title: 'Currency',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            underline: const SizedBox(),
                            items: <String>['KSh', 'USD', 'EUR', 'GBP']
                                .map<DropdownMenuItem<String>>((String value) =>
                                    DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        )))
                                .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                _saveCurrencyPreference(newValue);
                                SnackbarHelper.showSuccess(context, 'Currency updated!');
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Account Section
                  _buildSectionHeader('Account'),
                  const SizedBox(height: 12),
                  _buildModernCard(
                    children: [
                      _buildSettingTile(
                        icon: Icons.password,
                        title: 'Change Password',
                        onTap: _sendPasswordResetEmail,
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        icon: Icons.delete_forever,
                        title: 'Delete Account',
                        titleColor: Colors.red,
                        iconColor: Colors.red,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Data & Sync Section
                  _buildSectionHeader('Data & Sync'),
                  const SizedBox(height: 12),
                  _buildModernCard(
                    children: [
                      _buildSettingTile(
                        icon: Icons.cloud_download_outlined,
                        title: 'Restore from Cloud',
                        subtitle: 'Download your backup on a new device',
                        trailing: _isRestoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF4CAF50),
                                ))
                            : const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: _isRestoring ? null : _handleRestore,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Help & Support Section
                  _buildSectionHeader('Help & Support'),
                  const SizedBox(height: 12),
                  _buildModernCard(
                    children: [
                      _buildSettingTile(
                        icon: Icons.question_answer_outlined,
                        title: 'FAQ',
                        onTap: _showFaqDialog,
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        icon: Icons.support_agent,
                        title: 'Contact via WhatsApp',
                        onTap: _launchWhatsApp,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoggingOut ? null : _logout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ))
                          : const Icon(Icons.logout),
                      label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF4CAF50)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? const Color(0xFF4CAF50),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null),
      onTap: onTap,
    );
  }
}
