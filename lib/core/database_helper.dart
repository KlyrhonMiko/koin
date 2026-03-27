import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('koin.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN accountId TEXT DEFAULT "default_account"');
      await _createAccountsTable(db);
      await _insertDefaultAccounts(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN toAccountId TEXT');
    }
    if (oldVersion < 4) {
      await _createSavingsTables(db);
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE categories ADD COLUMN budget REAL');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE categories ADD COLUMN type TEXT DEFAULT "expense"');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE categories ADD COLUMN budgetPercent REAL');
      await db.execute('ALTER TABLE categories ADD COLUMN isPercentBudget INTEGER DEFAULT 0');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE accounts ADD COLUMN excludeFromTotal INTEGER DEFAULT 0');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE accounts ADD COLUMN position INTEGER DEFAULT 0');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE categories ADD COLUMN position INTEGER DEFAULT 0');
    }
  }

  Future _createSavingsTables(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE savings_goals (
  id $idType,
  name $textType,
  targetAmount $realType,
  currentAmount $realType,
  startDate $textType,
  endDate $textType,
  notes TEXT
)
''');

    await db.execute('''
CREATE TABLE savings_logs (
  id $idType,
  goalId $textType,
  amount $realType,
  date $textType,
  note TEXT,
  FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
)
''');
  }

  Future _createAccountsTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE accounts (
  id $idType,
  name $textType,
  iconCodePoint $intType,
  colorHex $textType,
  initialBalance $realType,
  excludeFromTotal INTEGER DEFAULT 0,
  position INTEGER DEFAULT 0
)
''');
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE categories (
  id $idType,
  name $textType,
  iconCodePoint $intType,
  colorHex $textType,
  type $textType,
  budget REAL,
  budgetPercent REAL,
  isPercentBudget INTEGER DEFAULT 0,
  position INTEGER DEFAULT 0
)
''');

    await _createAccountsTable(db);

    await db.execute('''
CREATE TABLE transactions (
  id $idType,
  title $textType,
  amount $realType,
  date $textType,
  type $textType,
  categoryId $textType,
  accountId $textType,
  toAccountId TEXT,
  FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL,
  FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE SET NULL,
  FOREIGN KEY (toAccountId) REFERENCES accounts (id) ON DELETE SET NULL
)
''');

    await _createSavingsTables(db);

    // Insert default data
    await _insertDefaultCategories(db);
    await _insertDefaultAccounts(db);
  }

  Future _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      TransactionCategory(id: 'cat_groceries', name: 'Groceries', iconCodePoint: Icons.shopping_cart.codePoint, colorHex: '#4CAF50', type: TransactionType.expense),
      TransactionCategory(id: 'cat_dining', name: 'Dining', iconCodePoint: Icons.restaurant.codePoint, colorHex: '#FF9800', type: TransactionType.expense),
      TransactionCategory(id: 'cat_transport', name: 'Transport', iconCodePoint: Icons.directions_car.codePoint, colorHex: '#2196F3', type: TransactionType.expense),
      TransactionCategory(id: 'cat_salary', name: 'Salary', iconCodePoint: Icons.attach_money.codePoint, colorHex: '#8BC34A', type: TransactionType.income),
      TransactionCategory(id: 'cat_entertainment', name: 'Entertainment', iconCodePoint: Icons.movie.codePoint, colorHex: '#9C27B0', type: TransactionType.expense),
      TransactionCategory(id: 'cat_health', name: 'Health', iconCodePoint: Icons.local_hospital.codePoint, colorHex: '#F44336', type: TransactionType.expense),
      TransactionCategory(id: 'cat_others', name: 'Others', iconCodePoint: Icons.category.codePoint, colorHex: '#607D8B', type: TransactionType.expense),
      TransactionCategory(id: 'cat_others_inc', name: 'Other Income', iconCodePoint: Icons.add_circle.codePoint, colorHex: '#00D09E', type: TransactionType.income),
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  Future _insertDefaultAccounts(Database db) async {
    final defaultAccounts = [
      Account(id: 'default_account', name: 'Cash', iconCodePoint: Icons.payments.codePoint, colorHex: '#4CAF50', position: 0),
      Account(id: 'bank_account', name: 'Bank', iconCodePoint: Icons.account_balance.codePoint, colorHex: '#2196F3', position: 1),
      Account(id: 'savings_account', name: 'Savings', iconCodePoint: Icons.savings.codePoint, colorHex: '#FF9800', position: 2),
    ];

    for (var account in defaultAccounts) {
      await db.insert('accounts', account.toMap());
    }
  }

  // Categories commands
  Future<TransactionCategory> insertCategory(TransactionCategory category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<List<TransactionCategory>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'position ASC');
    return result.map((json) => TransactionCategory.fromMap(json)).toList();
  }

  Future<int> updateCategory(TransactionCategory category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCategoryPositions(List<TransactionCategory> categories) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var category in categories) {
        batch.update(
          'categories',
          {'position': category.position},
          where: 'id = ?',
          whereArgs: [category.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // Accounts commands
  Future<Account> insertAccount(Account account) async {
    final db = await instance.database;
    await db.insert('accounts', account.toMap());
    return account;
  }

  Future<List<Account>> getAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts', orderBy: 'position ASC');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<int> updateAccount(Account account) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await instance.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAccountPositions(List<Account> accounts) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var account in accounts) {
        batch.update(
          'accounts',
          {'position': account.position},
          where: 'id = ?',
          whereArgs: [account.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // Transactions commands
  Future<AppTransaction> insertTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    await db.insert('transactions', transaction.toMap());
    return transaction;
  }

  Future<List<AppTransaction>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => AppTransaction.fromMap(json)).toList();
  }

  Future<int> updateTransaction(AppTransaction transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Savings Goals commands
  Future<SavingsGoal> insertSavingsGoal(SavingsGoal goal) async {
    final db = await instance.database;
    await db.insert('savings_goals', goal.toMap());
    return goal;
  }

  Future<List<SavingsGoal>> getSavingsGoals() async {
    final db = await instance.database;
    final result = await db.query('savings_goals');
    return result.map((json) => SavingsGoal.fromMap(json)).toList();
  }

  Future<int> updateSavingsGoal(SavingsGoal goal) async {
    final db = await instance.database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingsGoal(String id) async {
    final db = await instance.database;
    return await db.delete(
      'savings_goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Savings Logs commands
  Future<SavingsLog> insertSavingsLog(SavingsLog log) async {
    final db = await instance.database;
    await db.insert('savings_logs', log.toMap());
    
    // Update currentAmount in savings_goals
    await db.execute(
      'UPDATE savings_goals SET currentAmount = currentAmount + ? WHERE id = ?',
      [log.amount, log.goalId],
    );
    
    return log;
  }

  Future<List<SavingsLog>> getSavingsLogs(String goalId) async {
    final db = await instance.database;
    final result = await db.query(
      'savings_logs',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return result.map((json) => SavingsLog.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
