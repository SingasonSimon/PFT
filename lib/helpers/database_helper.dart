// lib/helpers/database_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/bill.dart';
import '../models/transaction.dart' as model;
import '../models/category.dart';

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
    String path = join(await getDatabasesPath(), 'PatoTrack.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconCodePoint INTEGER,
        colorValue INTEGER,
        userId TEXT NOT NULL
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
        userId TEXT NOT NULL,
        tag TEXT NOT NULL DEFAULT 'business'
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
  }

  Future<int> addTransaction(model.Transaction transaction, String userId) async {
    final db = await database;
    final newId = await db.insert('transactions', transaction.toMap()..['userId'] = userId);
    try {
      final docData = transaction.toMap()..['id'] = newId..['userId'] = userId;
      await _firestore.collection('users').doc(userId).collection('transactions').doc(newId.toString()).set(docData);
    } catch (e) {
      print('Firestore sync failed for addTransaction: $e');
    }
    return newId;
  }

  Future<List<model.Transaction>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => model.Transaction.fromMap(maps[i]));
  }

  Future<int> deleteTransaction(int id, String userId) async {
    final db = await database;
    final result = await db.delete('transactions', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore.collection('users').doc(userId).collection('transactions').doc(id.toString()).delete();
    } catch (e) {
      print('Firestore sync failed for deleteTransaction: $e');
    }
    return result;
  }

  Future<int> addCategory(Category category, String userId) async {
    final db = await database;
    final newId = await db.insert('categories', category.toMap()..['userId'] = userId);
    try {
      final docData = category.toMap()..['id'] = newId..['userId'] = userId;
      await _firestore.collection('users').doc(userId).collection('categories').doc(newId.toString()).set(docData);
    } catch(e) {
      print('Firestore sync failed for addCategory: $e');
    }
    return newId;
  }

  Future<List<Category>> getCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', where: 'userId = ?', whereArgs: [userId], orderBy: 'name');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }
  
  Future<int> deleteCategory(int id, String userId) async {
    final db = await database;
    final result = await db.delete('categories', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    try {
      await _firestore.collection('users').doc(userId).collection('categories').doc(id.toString()).delete();
    } catch (e) {
      print('Firestore sync failed for deleteCategory: $e');
    }
    return result;
  }

  Future<Category?> getCategoryByName(String name, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', where: 'UPPER(name) = ? AND userId = ?', whereArgs: [name.toUpperCase(), userId]);
    if (maps.isNotEmpty) return Category.fromMap(maps.first);
    return null;
  }

  Future<int> getOrCreateCategory(String name, String userId) async {
    print("--- Searching for category: '$name' for user: $userId ---");
    final existingCategory = await getCategoryByName(name, userId);

    if (existingCategory != null && existingCategory.id != null) {
      print("--- Found existing category with ID: ${existingCategory.id} ---");
      return existingCategory.id!;
    } else {
      print("--- Category NOT found. Creating a new one... ---");
      final newCategory = Category(name: name);
      final newId = await addCategory(newCategory, userId);
      print("--- Created new category with ID: $newId ---");
      return newId;
    }
  }

  Future<int> addBill(Bill bill, String userId) async {
    final db = await database;
    final newId = await db.insert('bills', bill.toMap()..['userId'] = userId);
    try {
      final docData = bill.toMap()..['id'] = newId..['userId'] = userId;
      await _firestore.collection('users').doc(userId).collection('bills').doc(newId.toString()).set(docData);
    } catch (e) {
      print('Firestore sync failed for addBill: $e');
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
      print('Firestore sync failed for deleteBill: $e');
    }
    return result;
  }

  Future<int> updateBill(Bill bill, String userId) async {
    final db = await database;
    final result = await db.update('bills', bill.toMap(), where: 'id = ? AND userId = ?', whereArgs: [bill.id, userId]);
    try {
      await _firestore.collection('users').doc(userId).collection('bills').doc(bill.id.toString()).update(bill.toMap());
    } catch (e) {
      print('Firestore sync failed for updateBill: $e');
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
    print('--- Successfully restored data from Firestore ---');
  }
}