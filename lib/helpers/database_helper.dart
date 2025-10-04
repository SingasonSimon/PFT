// lib/helpers/database_helper.dart

import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/bill.dart';
import '../models/transaction.dart';
import '../models/savings.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'PatoTrack.db');
    return await openDatabase(
      path,
      version: 4,
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
        userId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE savings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goalName TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0,
        userId TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE bills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        userId TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN userId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN userId TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE savings ADD COLUMN userId TEXT');
      await db.execute('ALTER TABLE bills ADD COLUMN userId TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE categories ADD COLUMN iconCodePoint INTEGER');
      await db.execute('ALTER TABLE categories ADD COLUMN colorValue INTEGER');
    }
  }

  // Transaction Functions
  Future<int> addTransaction(Transaction transaction, String userId) async {
    final db = await database;
    final map = transaction.toMap();
    map['userId'] = userId;
    return db.insert('transactions', map);
  }

  Future<List<Transaction>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<int> deleteTransaction(int id, String userId) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // Category Functions
  Future<int> addCategory(Category category, String userId) async {
    final db = await database;
    final map = category.toMap();
    map['userId'] = userId;
    return db.insert('categories', map);
  }

  Future<List<Category>> getCategories(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', where: 'userId = ?', whereArgs: [userId], orderBy: 'name');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }
  
  Future<int> deleteCategory(int id, String userId) async {
    final db = await database;
    return db.delete('categories', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // CORRECTED: This function is now case-insensitive to prevent duplicate categories.
  Future<Category?> getCategoryByName(String name, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'UPPER(name) = ? AND userId = ?',
      whereArgs: [name.toUpperCase(), userId],
    );
    if (maps.isNotEmpty) return Category.fromMap(maps.first);
    return null;
  }

  Future<int> getOrCreateCategory(String name, String userId) async {
    final existingCategory = await getCategoryByName(name, userId);
    if (existingCategory != null && existingCategory.id != null) {
      return existingCategory.id!;
    } else {
      final newCategory = Category(name: name);
      final newId = await addCategory(newCategory, userId);
      return newId;
    }
  }

  // Savings Functions
  Future<int> addSavingsGoal(SavingsGoal goal, String userId) async {
    final db = await database;
    final map = goal.toMap();
    map['userId'] = userId;
    return db.insert('savings', map);
  }

  Future<List<SavingsGoal>> getSavingsGoals(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('savings', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(maps.length, (i) => SavingsGoal.fromMap(maps[i]));
  }
  
  Future<int> updateSavingsGoal(SavingsGoal goal) async {
    final db = await database;
    return db.update('savings', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<int> deleteSavingsGoal(int id, String userId) async {
    final db = await database;
    return db.delete('savings', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // Bill Functions
  Future<int> addBill(Bill bill, String userId) async {
    final db = await database;
    final map = bill.toMap();
    map['userId'] = userId;
    return db.insert('bills', map);
  }

  Future<List<Bill>> getBills(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bills', where: 'userId = ?', whereArgs: [userId], orderBy: 'dueDate ASC');
    return List.generate(maps.length, (i) => Bill.fromMap(maps[i]));
  }
  
  Future<int> deleteBill(int id, String userId) async {
    final db = await database;
    return db.delete('bills', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }
}