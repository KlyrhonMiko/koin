import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/models/debt_repayment.dart';
import 'package:flutter/material.dart';
import 'dart:io';

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
      version: 25,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN accountId TEXT DEFAULT "default_account"',
        );
      } catch (e) {
        // Column might already exist
      }
      await _createAccountsTable(db);
      await _insertDefaultAccounts(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN toAccountId TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 4) {
      await _createSavingsTables(db);
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN budget REAL');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN type TEXT DEFAULT "expense"',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN budgetPercent REAL',
        );
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN isPercentBudget INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE accounts ADD COLUMN excludeFromTotal INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist if table was created in version 2-7
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE accounts ADD COLUMN position INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist if table was created in version 2-8
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          'ALTER TABLE categories ADD COLUMN position INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 11) {
      await db.execute('''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    }
    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE savings_goals ADD COLUMN linkedAccountId TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 13) {
      // Rename default "Dining" to "Food"
      await db.execute(
        "UPDATE categories SET name = 'Food' WHERE id = 'cat_dining' AND name = 'Dining'",
      );
    }
    if (oldVersion < 14) {
      await _createPlannedPaymentsTable(db);
    }
    if (oldVersion < 15) {
      await _createDebtsTables(db);
    }
    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE planned_payments ADD COLUMN notes TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 17) {
      try {
        await db.execute(
          'ALTER TABLE debts ADD COLUMN frequency TEXT DEFAULT "monthly"',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN logoAsset TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN cardColorHex TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 20) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN plannedPaymentId TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 21) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN debtRepaymentId TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 22) {
      try {
        await db.execute(
          'ALTER TABLE accounts ADD COLUMN cardShapeType INTEGER',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute(
          'ALTER TABLE debt_repayments ADD COLUMN isIncrease INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 24) {
      try {
        await db.execute(
          'ALTER TABLE debts ADD COLUMN categoryId TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 25) {
      try {
        await db.execute(
          'ALTER TABLE debts ADD COLUMN sortOrder INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist
      }
    }
  }

  Future _createPlannedPaymentsTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE planned_payments (
  id $idType,
  title $textType,
  amount $realType,
  type $textType,
  categoryId $textType,
  accountId $textType,
  startDate $textType,
  endDate TEXT,
  nextDate $textType,
  frequency $textType,
  notes TEXT,
  isAutoProcess INTEGER DEFAULT 0,
  FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL,
  FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE SET NULL
)
''');
  }

  Future _createDebtsTables(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE debts (
  id $idType,
  personName $textType,
  description TEXT,
  amount $realType,
  currentAmount $realType,
  type $textType,
  startDate $textType,
  dueDate TEXT,
  totalInstallments INTEGER DEFAULT 0,
  frequency TEXT DEFAULT "monthly",
  accountId TEXT,
  categoryId TEXT
)
''');

    await db.execute('''
CREATE TABLE debt_repayments (
  id $idType,
  debtId $textType,
  amount $realType,
  date $textType,
  note TEXT,
  accountId TEXT,
  isIncrease INTEGER DEFAULT 0,
  FOREIGN KEY (debtId) REFERENCES debts (id) ON DELETE CASCADE
)
''');
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
  notes TEXT,
  linkedAccountId TEXT
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
  position INTEGER DEFAULT 0,
  logoAsset TEXT,
  cardColorHex TEXT,
  cardShapeType INTEGER
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

    await db.execute('''
CREATE TABLE app_settings (
  key $idType,
  value $textType
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
  plannedPaymentId TEXT,
  debtRepaymentId TEXT,
  FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL,
  FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE SET NULL,
  FOREIGN KEY (toAccountId) REFERENCES accounts (id) ON DELETE SET NULL,
  FOREIGN KEY (plannedPaymentId) REFERENCES planned_payments (id) ON DELETE SET NULL,
  FOREIGN KEY (debtRepaymentId) REFERENCES debt_repayments (id) ON DELETE SET NULL
)
''');

    await _createSavingsTables(db);
    await _createPlannedPaymentsTable(db);
    await _createDebtsTables(db);

    // Insert default data
    await _insertDefaultCategories(db);
    await _insertDefaultAccounts(db);
  }

  Future _insertDefaultCategories(DatabaseExecutor db) async {
    final defaultCategories = [
      TransactionCategory(
        id: 'cat_groceries',
        name: 'Groceries',
        iconCodePoint: Icons.shopping_cart.codePoint,
        colorHex: '#4CAF50',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_food',
        name: 'Food',
        iconCodePoint: Icons.restaurant.codePoint,
        colorHex: '#FF9800',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_transport',
        name: 'Transport',
        iconCodePoint: Icons.directions_car.codePoint,
        colorHex: '#2196F3',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_salary',
        name: 'Salary',
        iconCodePoint: Icons.attach_money.codePoint,
        colorHex: '#8BC34A',
        type: TransactionType.income,
      ),
      TransactionCategory(
        id: 'cat_entertainment',
        name: 'Entertainment',
        iconCodePoint: Icons.movie.codePoint,
        colorHex: '#9C27B0',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_health',
        name: 'Health',
        iconCodePoint: Icons.local_hospital.codePoint,
        colorHex: '#F44336',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_others',
        name: 'Others',
        iconCodePoint: Icons.category.codePoint,
        colorHex: '#607D8B',
        type: TransactionType.expense,
      ),
      TransactionCategory(
        id: 'cat_others_inc',
        name: 'Other Income',
        iconCodePoint: Icons.add_circle.codePoint,
        colorHex: '#00D09E',
        type: TransactionType.income,
      ),
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  Future _insertDefaultAccounts(DatabaseExecutor db) async {
    final defaultAccounts = [
      Account(
        id: 'default_account',
        name: 'Cash',
        iconCodePoint: Icons.payments_rounded.codePoint,
        colorHex: '#00D09E',
        position: 0,
      ),
      Account(
        id: 'bank_account',
        name: 'Bank',
        iconCodePoint: Icons.account_balance_rounded.codePoint,
        colorHex: '#3B82F6',
        position: 1,
      ),
      Account(
        id: 'savings_account',
        name: 'Savings',
        iconCodePoint: Icons.savings_rounded.codePoint,
        colorHex: '#F59E0B',
        position: 2,
      ),
    ];

    for (var account in defaultAccounts) {
      await db.insert('accounts', account.toMap());
    }
  }

  // Data Deletion Commands
  Future<void> deleteAllTransactions() async {
    final db = await instance.database;
    await db.delete('transactions');
  }

  Future<void> deleteAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('savings_logs');
      await txn.delete('savings_goals');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('planned_payments');
      await txn.delete('debt_repayments');
      await txn.delete('debts');
      await txn.delete('app_settings');
    });
  }

  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'koin.db');
    await deleteDatabase(path);
    // Initialize again
    await database;
  }

  // Categories commands
  Future<TransactionCategory> insertCategory(
    TransactionCategory category,
  ) async {
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
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCategoryPositions(
    List<TransactionCategory> categories,
  ) async {
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
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
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

  Future<Map<String, dynamic>> deleteTransaction(String id) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Get the transaction
      final maps = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      String? rolledBackPlannedPaymentId;
      String? affectedDebtId;

      if (maps.isNotEmpty) {
        final transaction = AppTransaction.fromMap(maps.first);

        // 2. Check if it's linked to a planned payment
        if (transaction.plannedPaymentId != null) {
          final ppMaps = await txn.query(
            'planned_payments',
            where: 'id = ?',
            whereArgs: [transaction.plannedPaymentId],
          );

          if (ppMaps.isNotEmpty) {
            final payment = PlannedPayment.fromMap(ppMaps.first);

            // 3. Rollback nextDate
            DateTime prevDate = payment.nextDate;
            switch (payment.frequency) {
              case PaymentFrequency.daily:
                prevDate = prevDate.subtract(const Duration(days: 1));
                break;
              case PaymentFrequency.weekly:
                prevDate = prevDate.subtract(const Duration(days: 7));
                break;
              case PaymentFrequency.biWeekly:
                prevDate = prevDate.subtract(const Duration(days: 14));
                break;
              case PaymentFrequency.monthly:
                prevDate = DateTime(
                  prevDate.year,
                  prevDate.month - 1,
                  prevDate.day,
                );
                break;
              case PaymentFrequency.quarterly:
                prevDate = DateTime(
                  prevDate.year,
                  prevDate.month - 3,
                  prevDate.day,
                );
                break;
              case PaymentFrequency.yearly:
                prevDate = DateTime(
                  prevDate.year - 1,
                  prevDate.month,
                  prevDate.day,
                );
                break;
            }

            // 4. Update the planned payment
            await txn.update(
              'planned_payments',
              {'nextDate': prevDate.toIso8601String()},
              where: 'id = ?',
              whereArgs: [payment.id],
            );
            rolledBackPlannedPaymentId = payment.id;
          }
        }

        // 6. Check if it's linked to a debt repayment
        if (transaction.debtRepaymentId != null) {
          final repaymentMaps = await txn.query(
            'debt_repayments',
            where: 'id = ?',
            whereArgs: [transaction.debtRepaymentId],
          );

          if (repaymentMaps.isNotEmpty) {
            final repayment = DebtRepayment.fromMap(repaymentMaps.first);
            affectedDebtId = repayment.debtId;

            // Delete the debt repayment
            await txn.delete(
              'debt_repayments',
              where: 'id = ?',
              whereArgs: [repayment.id],
            );

            // Update the debt's currentAmount
            await txn.execute(
              'UPDATE debts SET currentAmount = currentAmount - ? WHERE id = ?',
              [repayment.amount, repayment.debtId],
            );
          }
        }
      }

      // 7. Delete the transaction
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);

      return {
        'plannedPaymentId': rolledBackPlannedPaymentId,
        'debtId': affectedDebtId,
      };
    });
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
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
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

  Future<void> deleteSavingsLog(SavingsLog log) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('savings_logs', where: 'id = ?', whereArgs: [log.id]);
      await txn.execute(
        'UPDATE savings_goals SET currentAmount = currentAmount - ? WHERE id = ?',
        [log.amount, log.goalId],
      );
    });
  }

  Future<void> updateSavingsLog(SavingsLog oldLog, SavingsLog newLog) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'savings_logs',
        newLog.toMap(),
        where: 'id = ?',
        whereArgs: [newLog.id],
      );
      final difference = newLog.amount - oldLog.amount;
      await txn.execute(
        'UPDATE savings_goals SET currentAmount = currentAmount + ? WHERE id = ?',
        [difference, newLog.goalId],
      );
    });
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

  // Planned Payments commands
  Future<PlannedPayment> insertPlannedPayment(PlannedPayment payment) async {
    final db = await instance.database;
    await db.insert('planned_payments', payment.toMap());
    return payment;
  }

  Future<List<PlannedPayment>> getPlannedPayments() async {
    final db = await instance.database;
    final result = await db.query('planned_payments', orderBy: 'nextDate ASC');
    return result.map((json) => PlannedPayment.fromMap(json)).toList();
  }

  Future<int> updatePlannedPayment(PlannedPayment payment) async {
    final db = await instance.database;
    return await db.update(
      'planned_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePlannedPayment(String id) async {
    final db = await instance.database;
    return await db.delete(
      'planned_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Settings commands
  Future<void> saveSettingsToDb(Map<String, String> settings) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('app_settings');
      for (var entry in settings.entries) {
        await txn.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
        });
      }
    });
  }

  Future<Map<String, String>> loadSettingsFromDb() async {
    final db = await instance.database;
    try {
      final result = await db.query('app_settings');
      return {
        for (var row in result) row['key'] as String: row['value'] as String,
      };
    } catch (e) {
      return {};
    }
  }

  Future<void> updateDebtPositions(List<Debt> debts) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var debt in debts) {
        batch.update(
          'debts',
          {'sortOrder': debt.sortOrder},
          where: 'id = ?',
          whereArgs: [debt.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // Debts commands
  Future<Debt> insertDebt(Debt debt) async {
    final db = await instance.database;
    await db.insert('debts', debt.toMap());
    return debt;
  }

  Future<List<Debt>> getDebts() async {
    final db = await instance.database;
    final result = await db.query('debts', orderBy: 'sortOrder ASC, startDate DESC');
    return result.map((json) => Debt.fromMap(json)).toList();
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(String id) async {
    final db = await instance.database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // Debt Repayments commands
  Future<DebtRepayment> insertDebtRepayment(DebtRepayment repayment) async {
    final db = await instance.database;
    await db.insert('debt_repayments', repayment.toMap());

    // Update debts table based on whether this is an increase or repayment
    if (repayment.isIncrease) {
      await db.execute(
        'UPDATE debts SET amount = amount + ? WHERE id = ?',
        [repayment.amount, repayment.debtId],
      );
    } else {
      await db.execute(
        'UPDATE debts SET currentAmount = currentAmount + ? WHERE id = ?',
        [repayment.amount, repayment.debtId],
      );
    }

    return repayment;
  }

  Future<void> deleteDebtRepayment(DebtRepayment repayment) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'debt_repayments',
        where: 'id = ?',
        whereArgs: [repayment.id],
      );
      // Delete associated transaction
      await txn.delete(
        'transactions',
        where: 'debtRepaymentId = ?',
        whereArgs: [repayment.id],
      );
      
      // Reverse the effect on the debt
      if (repayment.isIncrease) {
        await txn.execute(
          'UPDATE debts SET amount = amount - ? WHERE id = ?',
          [repayment.amount, repayment.debtId],
        );
      } else {
        await txn.execute(
          'UPDATE debts SET currentAmount = currentAmount - ? WHERE id = ?',
          [repayment.amount, repayment.debtId],
        );
      }
    });
  }

  Future<List<DebtRepayment>> getDebtRepayments(String debtId) async {
    final db = await instance.database;
    final result = await db.query(
      'debt_repayments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
    return result.map((json) => DebtRepayment.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<String> getDatabaseFilePath() async {
    if (_database != null) {
      await _database!.rawQuery('PRAGMA wal_checkpoint(FULL)');
    }
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'koin.db');
  }

  Future<bool> restoreDatabase(String backupPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'koin.db');

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Delete any existing WAL and SHM files to prevent corruption of the restored DB
      final walFile = File('$path-wal');
      final shmFile = File('$path-shm');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      final sourceFile = File(backupPath);
      await sourceFile.copy(path);

      // Test initialization
      await database;
      return true;
    } catch (e) {
      debugPrint("Error restoring database: \$e");
      return false;
    }
  }
}
