import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../models/category.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  static const List<IconData> _selectableIcons = [
    Icons.shopping_cart, Icons.restaurant, Icons.house, Icons.flight,
    Icons.receipt, Icons.local_hospital, Icons.school, Icons.pets,
    Icons.phone_android, Icons.wifi, Icons.movie, Icons.spa,
    Icons.build, Icons.book, Icons.music_note, Icons.directions_car,
    Icons.attach_money, Icons.work, Icons.card_giftcard, Icons.savings,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refreshCategories() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    final expenseCats = await dbHelper.getCategories(currentUser!.uid, type: 'expense');
    final incomeCats = await dbHelper.getCategories(currentUser!.uid, type: 'income');
    if (mounted) {
      setState(() {
        _expenseCategories = expenseCats;
        _incomeCategories = incomeCats;
        _isLoading = false;
      });
    }
  }

  IconData _getIconForCategory(Category category) {
    if (category.iconCodePoint != null) {
      return IconData(category.iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    return Icons.label;
  }

  void _showCategoryDialog({Category? category, required String type}) {
    _nameController.text = category?.name ?? '';
    IconData? selectedIcon = category?.iconCodePoint != null
        ? IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons')
        : (type == 'expense' ? Icons.category : Icons.source);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? 'Add New ${type.capitalize()} Category' : 'Edit Category'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(hintText: 'Category Name')),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(selectedIcon),
                    title: const Text('Select Icon'),
                    onTap: () async {
                      final IconData? newIcon = await showDialog<IconData>(
                          context: context, builder: (context) => _buildIconPickerDialog());
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
                    if (_nameController.text.isNotEmpty && currentUser != null) {
                      if (category == null) {
                        final newCategory = Category(
                          name: _nameController.text.trim(),
                          iconCodePoint: selectedIcon?.codePoint,
                          type: type,
                        );
                        await dbHelper.addCategory(newCategory, currentUser!.uid);
                      } else {
                        final updatedCategory = category.copyWith(
                          name: _nameController.text.trim(),
                          iconCodePoint: selectedIcon?.codePoint,
                        );
                        await dbHelper.updateCategory(updatedCategory, currentUser!.uid);
                      }
                      Navigator.pop(context);
                      _refreshCategories();
                    }
                  },
                  child: Text(category == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIconPickerDialog() {
    return AlertDialog(
      title: const Text('Select an Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16),
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

  Widget _buildCategoryList(List<Category> categories, String type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('No $type categories yet. Tap the "+" button to add one!', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(_getIconForCategory(category), color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  onPressed: () => _showCategoryDialog(category: category, type: category.type),
                  tooltip: 'Edit Category',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                      _refreshCategories();
                    }
                  },
                  tooltip: 'Delete Category',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(_expenseCategories, 'expense'),
          _buildCategoryList(_incomeCategories, 'income'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showCategoryDialog(type: type);
        },
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
