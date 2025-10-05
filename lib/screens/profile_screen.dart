// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../helpers/config.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';
import '../theme_provider.dart';
import 'passcode_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final dbHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  late Future<List<Category>> _categoriesFuture;
  final _categoryController = TextEditingController();
  final _nameController = TextEditingController();

  User? get currentUser => _auth.currentUser;

  bool _isLoggingOut = false;
  bool _isUploading = false;
  bool _isRestoring = false;
  String _selectedCurrency = 'KSh';
  bool _isPasscodeEnabled = false;

  static const List<IconData> _selectableIcons = [
    Icons.shopping_cart, Icons.restaurant, Icons.house, Icons.flight,
    Icons.receipt, Icons.local_hospital, Icons.school, Icons.pets,
    Icons.phone_android, Icons.wifi, Icons.movie, Icons.spa,
    Icons.build, Icons.book, Icons.music_note, Icons.directions_car,
  ];

  @override
  void initState() {
    super.initState();
    _refreshCategoryList();
    _loadPreferences();
  }
  
  @override
  void dispose() {
    _categoryController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null || currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final stringToSign = 'timestamp=$timestamp${AppConfig.cloudinaryApiSecret}';
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();

      request.fields['api_key'] = AppConfig.cloudinaryApiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData);
        final imageUrl = responseJson['secure_url'];

        await currentUser!.updatePhotoURL(imageUrl);
        Fluttertoast.showToast(msg: 'Profile picture updated!');
      } else {
        final errorData = await response.stream.bytesToString();
        print('Cloudinary Error: $errorData');
        Fluttertoast.showToast(msg: 'Failed to upload image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      Fluttertoast.showToast(msg: 'Failed to upload image: $e');
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

  void _showUpdateNameDialog() {
    _nameController.text = currentUser?.displayName ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Your Name'),
        content: TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Full Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                await currentUser?.updateDisplayName(_nameController.text.trim());
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated successfully!')));
                  setState(() {});
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    if (currentUser?.email == null) return;
    try {
      await _auth.sendPasswordResetEmail(email: currentUser!.email!);
      Fluttertoast.showToast(msg: 'Password reset link sent to your email.');
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: e.message ?? 'An error occurred.');
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE ACCOUNT'),
        content: const Text('This is irreversible. All your data will be permanently deleted. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await currentUser?.delete();
        Fluttertoast.showToast(msg: 'Account deleted successfully.');
      } on FirebaseAuthException catch (e) {
        Fluttertoast.showToast(msg: e.message ?? 'Failed to delete account.');
      }
    }
  }
  
  IconData _getIconForCategory(Category category) {
    if (category.iconCodePoint != null) {
      return IconData(category.iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    return Icons.label;
  }

  Color _getColorForCategory(Category category) {
    return Theme.of(context).colorScheme.primaryContainer;
  }

  void _refreshCategoryList() {
    if (currentUser == null) return;
    setState(() {
      _categoriesFuture = dbHelper.getCategories(currentUser!.uid);
    });
  }

  void _showAddCategoryDialog() {
    _categoryController.clear();
    IconData? selectedIcon = Icons.label;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Category'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: _categoryController, autofocus: true, decoration: const InputDecoration(hintText: 'Category Name')),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(selectedIcon),
                  title: const Text('Select Icon'),
                  onTap: () async {
                    final IconData? newIcon = await showDialog<IconData>(context: context, builder: (context) => _buildIconPickerDialog());
                    if (newIcon != null) {
                      setDialogState(() => selectedIcon = newIcon);
                    }
                  },
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  if (_categoryController.text.isNotEmpty && currentUser != null) {
                    final newCategory = Category(name: _categoryController.text.trim(), iconCodePoint: selectedIcon?.codePoint);
                    await dbHelper.addCategory(newCategory, currentUser!.uid);
                    _categoryController.clear();
                    Navigator.pop(context);
                    _refreshCategoryList();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIconPickerDialog() {
    return AlertDialog(
      title: const Text('Select an Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemCount: _selectableIcons.length,
          itemBuilder: (context, index) {
            final icon = _selectableIcons[index];
            return InkWell(onTap: () => Navigator.of(context).pop(icon), borderRadius: BorderRadius.circular(50), child: Icon(icon, size: 32));
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
  
  Future<void> _logout() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoggingOut = true);
      await _auth.signOut();
    }
  }

  Future<void> _launchWhatsApp() async {
    const phoneNumber = '+254748088741';
    const message = 'Hello, I have a question about the PatoTrack app.';
    final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not launch WhatsApp. Is it installed?');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'An error occurred.');
    }
  }

  void _showFaqDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Frequently Asked Questions'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Getting Started',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Use the tabs at the bottom to navigate. Add transactions from the Dashboard, view charts in Reports, and manage your account in Settings.\n',
            ),
            Text(
              'How do I add a transaction?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Tap the "Add Transaction" button on the dashboard. Fill in the details and save.\n',
            ),
            Text(
              'How does the M-Pesa sync work?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'The app automatically reads your M-Pesa SMS messages to create transactions for you. It only reads messages from "MPESA".\n',
            ),
            Text(
              'How do I delete something?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'On the Dashboard, swipe a transaction from right to left. On the Settings page, tap the red trash can icon. All deletions will ask for confirmation.\n',
            ),
            Text(
              'Is my data private?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Yes. All your financial data is stored locally on your device and is linked only to your account. No one else can see your data.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

  Future<void> _handleRestore() async {
    if (currentUser == null) return;

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Cloud'),
        content: const Text('This will replace all local data with your cloud backup. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isRestoring = true);
      try {
        await dbHelper.restoreFromFirestore(currentUser!.uid);
        Fluttertoast.showToast(msg: "Data restored successfully! Please restart the app to see all changes.", toastLength: Toast.LENGTH_LONG);
        _refreshCategoryList();
      } catch (e) {
        Fluttertoast.showToast(msg: "Error restoring data: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      } finally {
        if (mounted) setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (currentUser != null)
              // UPDATED: Replaced UserAccountsDrawerHeader with a custom widget
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: (currentUser!.photoURL != null) ? NetworkImage(currentUser!.photoURL!) : null,
                            child: (currentUser!.photoURL == null) ? const Icon(Icons.person, size: 40) : null,
                          ),
                          if (_isUploading) const CircularProgressIndicator(strokeWidth: 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentUser!.displayName ?? 'User',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: _showUpdateNameDialog,
                                borderRadius: BorderRadius.circular(30),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            currentUser!.email ?? 'No email',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('App Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              trailing: Switch(value: themeProvider.themeMode == ThemeMode.dark, onChanged: (value) => themeProvider.toggleTheme(value)),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Passcode Lock'),
              trailing: Switch(
                value: _isPasscodeEnabled,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  if (value) {
                    final success = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (context) => const PasscodeScreen(isSettingPasscode: true)));
                    if (success == true) setState(() => _isPasscodeEnabled = true);
                  } else {
                    final success = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (context) => const PasscodeScreen(isSettingPasscode: false)));
                    if (success == true) {
                      await prefs.remove('passcode');
                      setState(() => _isPasscodeEnabled = false);
                    }
                  }
                },
              ),
            ),
            if (_isPasscodeEnabled)
              ListTile(
                leading: const Icon(Icons.phonelink_lock),
                title: const Text('Change Passcode'),
                onTap: () async {
                  final verified = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (context) => const PasscodeScreen(isSettingPasscode: false)));
                  if (verified == true) {
                    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (context) => const PasscodeScreen(isSettingPasscode: true)));
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('Currency'),
              trailing: DropdownButton<String>(
                value: _selectedCurrency,
                items: <String>['KSh', 'USD', 'EUR', 'GBP'].map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _saveCurrencyPreference(newValue);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Currency updated!')));
                  }
                },
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Change Password'),
              onTap: _sendPasswordResetEmail,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onTap: _deleteAccount,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Data & Sync', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Restore from Cloud'),
              subtitle: const Text('Download your backup on a new device.'),
              trailing: _isRestoring ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
              onTap: _isRestoring ? null : _handleRestore,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Help & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.question_answer_outlined),
              title: const Text('FAQ'),
              onTap: _showFaqDialog,
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Contact via WhatsApp'),
              onTap: _launchWhatsApp,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Manage Expense Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            FutureBuilder<List<Category>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const ListTile(title: Text('No categories yet. Add one!'));
                }
                final categories = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForCategory(category),
                          child: Icon(_getIconForCategory(category), color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        title: Text(category.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                             if (currentUser == null) return;
                            final bool? confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Are you sure you want to delete the "${category.name}" category?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await dbHelper.deleteCategory(category.id!, currentUser!.uid);
                               if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category Deleted')));
                              }
                              _refreshCategoryList();
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add New Category'),
              onTap: _showAddCategoryDialog,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: ElevatedButton.icon(
                    onPressed: _isLoggingOut ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: _isLoggingOut ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}