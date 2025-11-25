import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart' as app_category;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'PersonalFinanceTracker.db');
    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        type TEXT NOT NULL DEFAULT 'expense',
        iconCodePoint INTEGER,
        colorValue INTEGER,
        userId TEXT NOT NULL,
        UNIQUE(name, userId, type)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        category_id INTEGER,
        userId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE bills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        userId TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrenceType TEXT,
        recurrenceValue INTEGER
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN userId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN userId TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE bills ADD COLUMN userId TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE categories ADD COLUMN iconCodePoint INTEGER');
      await db.execute('ALTER TABLE categories ADD COLUMN colorValue INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE bills ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE bills ADD COLUMN recurrenceType TEXT');
      await db.execute('ALTER TABLE bills ADD COLUMN recurrenceValue INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE transactions ADD COLUMN tag TEXT NOT NULL DEFAULT 'business'");
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE categories ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
    }
    if (oldVersion < 8) {
      // Migrate: Convert all 'business' tags to 'personal' (for data consistency)
      await db.execute("UPDATE transactions SET tag = 'personal' WHERE tag = 'business'");
      
      // Remove tag column by recreating the table
      await db.execute('''
        CREATE TABLE transactions_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          category_id INTEGER,
          userId TEXT NOT NULL
        )
      ''');
      
      // Copy data from old table to new table (excluding tag column)
      await db.execute('''
        INSERT INTO transactions_new (id, type, amount, description, date, category_id, userId)
        SELECT id, type, amount, description, date, category_id, userId
        FROM transactions
      ''');
      
      // Drop old table and rename new one
      await db.execute('DROP TABLE transactions');
      await db.execute('ALTER TABLE transactions_new RENAME TO transactions');
    }
  }

  // --- Transaction Functions ---
  Future<int> addTransaction(model.Transaction transaction, String userId) async {
    final db = await database;
    final newId = await db.insert('transactions', transaction.toMap()..['userId'] = userId);
    // Firestore sync - don't block on this, use timeout to prevent hanging
    try {
      final docData = transaction.toMap()..['id'] = newId..['userId'] = userId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(newId.toString())
          .set(docData)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for addTransaction');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for addTransaction: $e');
    }
    return newId;
  }

  Future<List<model.Transaction>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => model.Transaction.fromMap(maps[i]));
  }

  // NEW: Function to update a transaction in both local DB and Firestore
  Future<int> updateTransaction(model.Transaction transaction, String userId) async {
    final db = await database;
    final result = await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [transaction.id, userId],
    );
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transaction.id.toString())
          .update(transaction.toMap())
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for updateTransaction');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for updateTransaction: $e');
    }
    return result;
  }

  Future<int> deleteTransaction(int id, String userId) async {
    final db = await database;
    final result = await db.delete('transactions', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(id.toString())
          .delete()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for deleteTransaction');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for deleteTransaction: $e');
    }
    return result;
  }

  // --- Category Functions ---
  Future<int> addCategory(app_category.Category category, String userId) async {
    final db = await database;
    
    // Check if category with same name and type already exists
    final existing = await getCategoryByName(category.name, userId, category.type);
    if (existing != null) {
      throw Exception('A category with the name "${category.name}" already exists for ${category.type} transactions.');
    }
    
    final map = category.toMap()..['userId'] = userId;
    final newId = await db.insert('categories', map);
    
    if (newId > 0) {
        try {
        final docData = category.toMap()..['id'] = newId..['userId'] = userId;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(newId.toString())
            .set(docData)
            .timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('Firestore sync timeout for addCategory');
        });
      } catch(e) {
        debugPrint('Firestore sync failed for addCategory: $e');
      }
    } else {
      throw Exception('Failed to add category - database returned ID: $newId');
    }
    
    return newId;
  }

  Future<int> updateCategory(app_category.Category category, String userId) async {
    final db = await database;
    final result = await db.update('categories', category.toMap(), where: 'id = ? AND userId = ?', whereArgs: [category.id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.id.toString())
          .update(category.toMap())
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for updateCategory');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for updateCategory: $e');
    }
    return result;
  }

  Future<List<app_category.Category>> getCategories(String userId, {String? type}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (type != null) {
      maps = await db.query('categories', where: 'userId = ? AND type = ?', whereArgs: [userId, type], orderBy: 'name');
    } else {
      maps = await db.query('categories', where: 'userId = ?', whereArgs: [userId], orderBy: 'name');
    }
    return List.generate(maps.length, (i) => app_category.Category.fromMap(maps[i]));
  }
  
  Future<int> deleteCategory(int id, String userId) async {
    final db = await database;
    final result = await db.delete('categories', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(id.toString())
          .delete()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for deleteCategory');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for deleteCategory: $e');
    }
    return result;
  }

  Future<app_category.Category?> getCategoryByName(String name, String userId, String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', where: 'name = ? AND userId = ? AND type = ?', whereArgs: [name, userId, type]);
    if (maps.isNotEmpty) return app_category.Category.fromMap(maps.first);
    return null;
  }
  
  Future<int> getOrCreateCategory(String name, String userId, {String type = 'expense'}) async {
    final existingCategory = await getCategoryByName(name, userId, type);
    if (existingCategory != null && existingCategory.id != null) {
      return existingCategory.id!;
    } else {
      final newCategory = app_category.Category(name: name, type: type);
      final newId = await addCategory(newCategory, userId);
      if (newId == 0) {
        final finalCategory = await getCategoryByName(name, userId, type);
        return finalCategory?.id ?? 0;
      }
      return newId;
    }
  }

  // --- Bill Functions ---
  Future<int> addBill(Bill bill, String userId) async {
    final db = await database;
    final newId = await db.insert('bills', bill.toMap()..['userId'] = userId);
    try {
      final docData = bill.toMap()..['id'] = newId..['userId'] = userId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .doc(newId.toString())
          .set(docData)
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('Firestore sync timeout for addBill');
      });
    } catch (e) {
      debugPrint('Firestore sync failed for addBill: $e');
    }
    return newId;
  }

  Future<List<Bill>> getBills(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bills', where: 'userId = ?', whereArgs: [userId], orderBy: 'dueDate ASC');
    return List.generate(maps.length, (i) => Bill.fromMap(maps[i]));
  }
  
  Future<int> deleteBill(int id, String userId) async {
    final db = await database;
    final result = await db.delete('bills', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore.collection('users').doc(userId).collection('bills').doc(id.toString()).delete();
    } catch (e) {
      debugPrint('Firestore sync failed for deleteBill: $e');
    }
    return result;
  }

  Future<int> updateBill(Bill bill, String userId) async {
    final db = await database;
    final result = await db.update('bills', bill.toMap(), where: 'id = ? AND userId = ?', whereArgs: [bill.id, userId]);
    try {
      await _firestore.collection('users').doc(userId).collection('bills').doc(bill.id.toString()).update(bill.toMap());
    } catch (e) {
      debugPrint('Firestore sync failed for updateBill: $e');
    }
    return result;
  }

  Future<void> restoreFromFirestore(String userId) async {
    final db = await database;
    final batch = db.batch();

    batch.delete('transactions', where: 'userId = ?', whereArgs: [userId]);
    batch.delete('categories', where: 'userId = ?', whereArgs: [userId]);
    batch.delete('bills', where: 'userId = ?', whereArgs: [userId]);

    final transactionSnap = await _firestore.collection('users').doc(userId).collection('transactions').get();
    for (final doc in transactionSnap.docs) {
      batch.insert('transactions', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final categorySnap = await _firestore.collection('users').doc(userId).collection('categories').get();
    for (final doc in categorySnap.docs) {
      batch.insert('categories', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final billSnap = await _firestore.collection('users').doc(userId).collection('bills').get();
    for (final doc in billSnap.docs) {
      batch.insert('bills', doc.data(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('--- Successfully restored data from Firestore ---');
  }
}

