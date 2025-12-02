import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../helpers/dialog_helper.dart';
import '../models/category.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dbHelper = DatabaseHelper();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  Set<int> _deletingCategoryIds = {}; // Track which categories are being deleted
  IconData? _selectedIconForDialog;
  ValueNotifier<bool>? _dialogLoadingState;

  final _nameController = TextEditingController();
  static const List<IconData> _selectableIcons = [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.house,
    Icons.flight,
    Icons.receipt,
    Icons.local_hospital,
    Icons.school,
    Icons.pets,
    Icons.phone_android,
    Icons.wifi,
    Icons.movie,
    Icons.spa,
    Icons.build,
    Icons.book,
    Icons.music_note,
    Icons.directions_car,
    Icons.attach_money,
    Icons.work,
    Icons.card_giftcard,
    Icons.savings,
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
    _dialogLoadingState?.dispose();
    super.dispose();
  }

  Future<void> _refreshCategories() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final expenseCats =
          await dbHelper.getCategories(currentUser!.uid, type: 'expense');
      final incomeCats =
          await dbHelper.getCategories(currentUser!.uid, type: 'income');
    if (mounted) {
      setState(() {
        _expenseCategories = expenseCats;
        _incomeCategories = incomeCats;
        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarHelper.showError(context, 'Failed to load categories');
      }
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
    _selectedIconForDialog = category?.iconCodePoint != null
        ? IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons')
        : (type == 'expense' ? Icons.category : Icons.source);

    // Create loading state once for this dialog
    _dialogLoadingState = ValueNotifier<bool>(false);
    
    // Store the screen's context before showing dialog
    final screenContext = context;

    DialogHelper.showModernDialog(
      context: context,
      title: category == null
          ? 'Add ${type.capitalize()} Category'
          : 'Edit Category',
      content: StatefulBuilder(
          builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Category Name',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
                  const SizedBox(height: 20),
              GestureDetector(
                    onTap: () async {
                      final IconData? newIcon = await showDialog<IconData>(
                    context: context,
                    builder: (context) => _buildIconPickerDialog(),
                  );
                      if (newIcon != null) {
                    setDialogState(() {
                      _selectedIconForDialog = newIcon;
                    });
                      }
                    },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _selectedIconForDialog,
                          color: const Color(0xFF4CAF50),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Icon',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
              ),
              actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _dialogLoadingState!,
          builder: (context, isSaving, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSaving ? null : () {
                    _dialogLoadingState?.dispose();
                    _dialogLoadingState = null;
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_nameController.text.trim().isEmpty ||
                              currentUser == null) {
                            return;
                          }

                          _dialogLoadingState!.value = true;

                          try {
                            bool success = false;
                            String message = '';
                            
                      if (category == null) {
                        final newCategory = Category(
                          name: _nameController.text.trim(),
                                iconCodePoint: _selectedIconForDialog?.codePoint,
                          type: type,
                        );
                              await dbHelper.addCategory(
                                  newCategory, currentUser!.uid);
                              // addCategory now throws exception on failure, so if we get here, it succeeded
                              success = true;
                              message = 'Category added successfully!';
                      } else {
                              // Ensure we preserve the category ID when updating
                              if (category.id == null) {
                                throw Exception('Cannot update category without ID');
                              }
                        final updatedCategory = category.copyWith(
                          name: _nameController.text.trim(),
                                iconCodePoint: _selectedIconForDialog?.codePoint,
                        );
                              await dbHelper.updateCategory(
                                  updatedCategory, currentUser!.uid);
                              // updateCategory throws exception on failure, so if we get here, it succeeded
                              success = true;
                              message = 'Category updated successfully!';
                            }
                            
                            if (success && mounted) {
                              // Dispose loading state
                              _dialogLoadingState?.dispose();
                              _dialogLoadingState = null;
                              // Close dialog
                      Navigator.pop(context);
                              // Refresh categories and show success using screen context
                              if (mounted) {
                                await _refreshCategories();
                                SnackbarHelper.showSuccess(screenContext, message);
                    }
                            }
                          } catch (e) {
                            if (mounted) {
                              _dialogLoadingState!.value = false;
                              SnackbarHelper.showError(
                                  context, 'Failed to save category: $e');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          category == null ? 'Add' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildIconPickerDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select an Icon',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
          itemCount: _selectableIcons.length,
          itemBuilder: (context, index) {
            final icon = _selectableIcons[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(icon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  );
          },
        ),
      ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, String type) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4CAF50),
        ),
      );
    }
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No $type categories yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add one!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForCategory(category),
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  onPressed: _isDeleting || _deletingCategoryIds.contains(category.id)
                      ? null
                      : () => _showCategoryDialog(
                            category: category,
                            type: category.type,
                          ),
                  tooltip: 'Edit Category',
                ),
                IconButton(
                  icon: _deletingCategoryIds.contains(category.id)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isDeleting || _deletingCategoryIds.contains(category.id)
                      ? null
                      : () async {
                          final bool? confirm =
                              await DialogHelper.showConfirmDialog(
                      context: context,
                            title: 'Delete Category',
                            message:
                                'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
                            confirmText: 'Delete',
                            confirmColor: Colors.red,
                    );
                          if (confirm == true && currentUser != null && category.id != null) {
                            setState(() {
                              _deletingCategoryIds.add(category.id!);
                            });
                            try {
                              await dbHelper.deleteCategory(
                                  category.id!, currentUser!.uid);
                              if (mounted) {
                                await _refreshCategories();
                                SnackbarHelper.showSuccess(context,
                                    'Category deleted successfully!');
                              }
                            } catch (e) {
                              if (mounted) {
                                SnackbarHelper.showError(
                                    context, 'Failed to delete category: $e');
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _deletingCategoryIds.remove(category.id!);
                                });
                              }
                            }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Categories',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4CAF50),
          indicatorWeight: 3,
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
        onPressed: _isDeleting
            ? null
            : () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showCategoryDialog(type: type);
        },
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
