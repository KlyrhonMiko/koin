import 'package:koin/core/models/models.dart';
import 'package:koin/core/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class CategorizationResult {
  final String originId;
  final String destinationId;
  final TransactionType type;
  final double confidence;
  final bool isExactMatch;

  CategorizationResult({
    required this.originId,
    required this.destinationId,
    required this.type,
    required this.confidence,
    this.isExactMatch = false,
  });
}

class CategorizationEngine {
  final DatabaseHelper _dbHelper;
  final Uuid _uuid = const Uuid();

  CategorizationEngine({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // Phase 2: Sanitization & Tokenization

  List<String> _tokenize(String rawText) {
    // Strip all non-alphabetical characters and convert to lowercase
    final sanitized = rawText
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), '')
        .toLowerCase();

    // Split into isolated words
    final words = sanitized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Filter out common stop words and short tokens (< 3 characters)
    final stopWords = {
      'the',
      'and',
      'for',
      'with',
      'from',
      'that',
      'this',
      'was',
      'out',
      'are',
    };
    return words.where((w) => w.length >= 3 && !stopWords.contains(w)).toList();
  }

  String _sanitize(String rawText) {
    return rawText
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase()
        .trim();
  }

  // Phase 3: The Routing Waterfall

  /// Evaluates a new transaction and attempts to auto-categorize it.
  /// Note: [amount] should be the signed value. If the app uses positive amounts
  /// with a separate `TransactionType`, pass the amount as positive for income,
  /// and negative for expense, or vice versa, to reflect the "mathematical sign"
  /// required by the engine.
  Future<CategorizationResult?> categorize({
    required String rawText,
    required double amount,
    required DateTime date,
    required String currentAccountId,
  }) async {
    await bootstrapFromHistory();
    final sanitizedString = _sanitize(rawText);
    final sign = amount >= 0 ? 1 : -1;
    final tokens = _tokenize(rawText);

    // Step 1: The Exact Match Layer
    final exactMatch = await _checkExactMatch(sanitizedString, sign);
    if (exactMatch != null) {
      return exactMatch;
    }

    // Step 2: The Internal Transfer Heuristic
    final internalTransfer = await _checkInternalTransfer(
      amount,
      date,
      currentAccountId,
    );
    if (internalTransfer != null) {
      return internalTransfer;
    }

    // Step 3: The Directional Probability Engine
    if (tokens.isEmpty) return null;
    return await _calculateProbability(tokens, sign, currentAccountId);
  }

  Future<CategorizationResult?> _checkExactMatch(
    String sanitizedString,
    int sign,
  ) async {
    if (sanitizedString.isEmpty) return null;

    final db = await _dbHelper.database;
    final results = await db.query(
      'categorization_rules',
      where: 'search_string = ?',
      whereArgs: [sanitizedString],
    );

    for (var rule in results) {
      final originId = rule['originId'] as String;
      final destinationId = rule['destinationId'] as String;

      final isTransferResult = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [destinationId],
      );
      final isTransfer = isTransferResult.isNotEmpty;

      if (isTransfer) {
        return CategorizationResult(
          originId: originId,
          destinationId: destinationId,
          type: TransactionType.transfer,
          confidence: 1.0, // 100% confidence for exact match
          isExactMatch: true,
        );
      }

      // Check category type against the requested sign
      final catResult = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [destinationId],
        limit: 1,
      );

      if (catResult.isNotEmpty) {
        final catType = catResult.first['type'] as String?;
        final expectedType = sign >= 0
            ? TransactionType.income.name
            : TransactionType.expense.name;

        if (catType == expectedType) {
          return CategorizationResult(
            originId: originId,
            destinationId: destinationId,
            type: sign >= 0 ? TransactionType.income : TransactionType.expense,
            confidence: 1.0, // 100% confidence for exact match
            isExactMatch: true,
          );
        }
      }
    }
    return null;
  }

  Future<CategorizationResult?> _checkInternalTransfer(
    double amount,
    DateTime date,
    String currentAccountId,
  ) async {
    final db = await _dbHelper.database;

    // We assume the DB stores amounts as positive numbers and uses TransactionType to denote sign.
    final absAmount = amount.abs();
    final targetType = amount >= 0
        ? TransactionType.expense.name
        : TransactionType.income.name;

    // 48-hour tight threshold
    final lowerBound = date
        .subtract(const Duration(hours: 48))
        .toIso8601String();
    final upperBound = date.add(const Duration(hours: 48)).toIso8601String();

    final results = await db.query(
      'transactions',
      where:
          'amount = ? AND date >= ? AND date <= ? AND type = ? AND accountId != ?',
      whereArgs: [
        absAmount,
        lowerBound,
        upperBound,
        targetType,
        currentAccountId,
      ],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final targetTx = results.first;
      final targetAccountId = targetTx['accountId'] as String;

      // Link them together as an internal movement
      final originId = amount >= 0 ? targetAccountId : currentAccountId;
      final destinationId = amount >= 0 ? currentAccountId : targetAccountId;

      return CategorizationResult(
        originId: originId,
        destinationId: destinationId,
        type: TransactionType.transfer,
        confidence: 1.0, // 100% confidence for internal transfers
        isExactMatch: false,
      );
    }
    return null;
  }

  Future<CategorizationResult?> _calculateProbability(
    List<String> tokens,
    int sign,
    String currentAccountId,
  ) async {
    final db = await _dbHelper.database;

    // Filter by Direction: retrieve token counts for the specific sign
    final placeholders = List.filled(tokens.length, '?').join(',');
    final queryArgs = [...tokens, sign];

    final results = await db.query(
      'ml_frequency_dictionary',
      where: 'token IN ($placeholders) AND sign = ?',
      whereArgs: queryArgs,
    );

    if (results.isEmpty) return null;

    final classCounts = <String, int>{};
    final tokenClassCounts = <String, Map<String, int>>{};
    int totalDocs = 0;

    // Aggregate probabilities against historical data matching the sign
    final classTotalsQuery = await db.rawQuery(
      'SELECT originId, destinationId, SUM(occurrences) as total FROM ml_frequency_dictionary WHERE sign = ? GROUP BY originId, destinationId',
      [sign],
    );

    for (var row in classTotalsQuery) {
      final classKey = '${row['originId']}|${row['destinationId']}';
      final total = (row['total'] as num).toInt();
      classCounts[classKey] = total;
      totalDocs += total;
    }

    if (totalDocs == 0) return null;

    for (var token in tokens) {
      tokenClassCounts[token] = {};
    }

    final uniqueClasses = classCounts.keys.toList();

    for (var row in results) {
      final token = row['token'] as String;
      final classKey = '${row['originId']}|${row['destinationId']}';
      final count = (row['occurrences'] as num).toInt();
      if (tokenClassCounts.containsKey(token)) {
        tokenClassCounts[token]![classKey] = count;
      }
    }

    double bestScore = -double.infinity;
    String? bestClass;

    // Naive Bayes with Laplace smoothing
    final vocabSizeQuery = await db.rawQuery(
      'SELECT COUNT(DISTINCT token) as count FROM ml_frequency_dictionary WHERE sign = ?',
      [sign],
    );
    final vocabSize = (vocabSizeQuery.first['count'] as num).toInt();

    // Score Calculation
    for (var classKey in uniqueClasses) {
      final classTotal = classCounts[classKey]!;
      double logProb = log(classTotal / totalDocs); // P(Class)

      for (var token in tokens) {
        final tokenCountInClass = tokenClassCounts[token]?[classKey] ?? 0;
        final probTokenGivenClass =
            (tokenCountInClass + 1) /
            (classTotal + vocabSize); // P(Token | Class)
        logProb += log(probTokenGivenClass);
      }

      if (logProb > bestScore) {
        bestScore = logProb;
        bestClass = classKey;
      }
    }

    if (bestClass == null) return null;

    // Convert to a normalized confidence score
    double sumExp = 0;
    for (var classKey in uniqueClasses) {
      double lp = log(classCounts[classKey]! / totalDocs);
      for (var token in tokens) {
        final tc = tokenClassCounts[token]?[classKey] ?? 0;
        lp += log((tc + 1) / (classCounts[classKey]! + vocabSize));
      }
      sumExp += exp(lp - bestScore);
    }

    final confidence = 1.0 / sumExp;

    // Threshold Check: Auto-apply if it exceeds 70% confidence
    if (confidence >= 0.70) {
      final parts = bestClass.split('|');
      final originId = parts[0];
      final destinationId = parts[1];

      final isTransferResult = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [destinationId],
      );
      final isTransfer = isTransferResult.isNotEmpty;

      if (isTransfer) {
        return CategorizationResult(
          originId: originId,
          destinationId: destinationId,
          type: TransactionType.transfer,
          confidence: confidence,
        );
      }

      // Validate category type matches the requested sign
      final catResult = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [destinationId],
        limit: 1,
      );

      if (catResult.isNotEmpty) {
        final catType = catResult.first['type'] as String?;
        final expectedType = sign >= 0
            ? TransactionType.income.name
            : TransactionType.expense.name;

        if (catType != expectedType) {
          return null; // Category type doesn't match transaction sign
        }

        return CategorizationResult(
          originId: originId,
          destinationId: destinationId,
          type: sign >= 0 ? TransactionType.income : TransactionType.expense,
          confidence: confidence,
        );
      }

      return null;
    }

    return null; // Leave blank for manual review
  }

  // Phase 4: The Feedback and Memory Loop

  /// Call this when a user categorizes an empty transaction or corrects an AI prediction.
  Future<void> processFeedback({
    required String rawText,
    required double amount,
    required String originId,
    required String destinationId,
  }) async {
    final db = await _dbHelper.database;
    final sanitized = _sanitize(rawText);
    if (sanitized.isEmpty) return;
    // Keep explicit feedback from debt/planned-payment forms separately from
    // ledger history so a history rebuild doesn't forget those choices.
    await db.transaction((txn) async {
      await txn.insert('categorization_feedback', {
        'id': '${amount >= 0 ? 1 : -1}|$sanitized',
        'rawText': rawText,
        'amount': amount,
        'originId': originId,
        'destinationId': destinationId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_settings', {
        'key': 'categorization_history_dirty',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await bootstrapFromHistory();
  }

  Future<void> _processFeedbackInternal({
    required DatabaseExecutor db,
    required String rawText,
    required double amount,
    required String originId,
    required String destinationId,
  }) async {
    final sanitizedString = _sanitize(rawText);
    final sign = amount >= 0 ? 1 : -1;
    final tokens = _tokenize(rawText);

    // 1. Lock in the Rule
    if (sanitizedString.isNotEmpty) {
      final ruleExists = await db.query(
        'categorization_rules',
        where: 'search_string = ?',
        whereArgs: [sanitizedString],
      );

      bool updated = false;
      for (var existing in ruleExists) {
        final existingDest = existing['destinationId'] as String;
        final isExistingTransfer = (await db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [existingDest],
        )).isNotEmpty;
        final isNewTransfer = (await db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [destinationId],
        )).isNotEmpty;

        if (isExistingTransfer && isNewTransfer) {
          await db.update(
            'categorization_rules',
            {'originId': originId, 'destinationId': destinationId},
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
          updated = true;
          break;
        } else if (!isExistingTransfer && !isNewTransfer) {
          final existingCat = await db.query(
            'categories',
            where: 'id = ?',
            whereArgs: [existingDest],
            limit: 1,
          );
          final existingType = existingCat.isNotEmpty
              ? existingCat.first['type'] as String?
              : null;
          final expectedType = sign >= 0
              ? TransactionType.income.name
              : TransactionType.expense.name;

          if (existingType == expectedType) {
            await db.update(
              'categorization_rules',
              {'originId': originId, 'destinationId': destinationId},
              where: 'id = ?',
              whereArgs: [existing['id']],
            );
            updated = true;
            break;
          }
        }
      }

      if (!updated) {
        await db.insert('categorization_rules', {
          'id': _uuid.v4(),
          'search_string': sanitizedString,
          'originId': originId,
          'destinationId': destinationId,
        });
      }
    }

    // 2. Adjust the Weights
    for (var token in tokens) {
      final existing = await db.query(
        'ml_frequency_dictionary',
        where: 'token = ? AND originId = ? AND destinationId = ? AND sign = ?',
        whereArgs: [token, originId, destinationId, sign],
      );

      if (existing.isEmpty) {
        await db.insert('ml_frequency_dictionary', {
          'id': _uuid.v4(),
          'token': token,
          'originId': originId,
          'destinationId': destinationId,
          'sign': sign,
          'occurrences': 1,
        });
      } else {
        final currentCount = (existing.first['occurrences'] as num).toInt();
        await db.update(
          'ml_frequency_dictionary',
          {'occurrences': currentCount + 1},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    }
  }

  /// Synchronizes the model with all saved transactions when history changes.
  /// Version 2 also repairs devices whose one-time bootstrap missed history.
  Future<void> bootstrapFromHistory() async {
    final db = await _dbHelper.database;
    // Read the marker and rebuild in one transaction so concurrent suggestions
    // cannot train the same history twice or clear a newer dirty marker.
    await db.transaction((txn) async {
      final settings = await txn.query(
        'app_settings',
        where: 'key IN (?, ?)',
        whereArgs: [
          'categorization_model_version',
          'categorization_history_dirty',
        ],
      );
      final values = {for (final row in settings) row['key']: row['value']};
      if (values['categorization_model_version'] == '2' &&
          values['categorization_history_dirty'] != 'true') {
        return;
      }

      // Rebuild rather than append: edits/deletions must remove old learning,
      // and repeated synchronization must not inflate token counts.
      await txn.delete('categorization_rules');
      await txn.delete('ml_frequency_dictionary');
      final accounts = await txn.query('accounts', columns: ['id']);
      final accountIds = accounts.map((row) => row['id']).toSet();
      final categories = await txn.query('categories', columns: ['id', 'type']);
      final categoryTypes = {
        for (final row in categories) row['id']: row['type'],
      };
      bool validDestination(String destinationId, double amount) =>
          accountIds.contains(destinationId) ||
          categoryTypes[destinationId] ==
              (amount >= 0
                  ? TransactionType.income.name
                  : TransactionType.expense.name);

      final feedback = await txn.query(
        'categorization_feedback',
        orderBy: 'id',
      );
      for (final sample in feedback) {
        final destinationId = sample['destinationId'] as String;
        final amount = (sample['amount'] as num).toDouble();
        if (!validDestination(destinationId, amount)) continue;
        await _processFeedbackInternal(
          db: txn,
          rawText: sample['rawText'] as String,
          amount: amount,
          originId: sample['originId'] as String,
          destinationId: destinationId,
        );
      }

      final transactions = await txn.query(
        'transactions',
        orderBy: 'date ASC, id ASC',
      );
      for (var tx in transactions) {
        final note = tx['title'] as String? ?? '';
        if (note.trim().isEmpty) continue;

        final amount = (tx['amount'] as num).toDouble();
        final type = tx['type'] as String;
        final accountId = tx['accountId'] as String?;
        if (accountId == null || !accountIds.contains(accountId)) continue;

        // Transfers use the outgoing direction, matching live feedback.
        final signedAmount = type == TransactionType.income.name
            ? (amount.abs() == 0 ? 1.0 : amount.abs())
            : -(amount.abs() == 0 ? 1.0 : amount.abs());
        final isTransfer = type == TransactionType.transfer.name;

        final destinationId = isTransfer
            ? (tx['toAccountId'] as String?)
            : (tx['categoryId'] as String?);

        if (destinationId != null &&
            validDestination(destinationId, signedAmount)) {
          await _processFeedbackInternal(
            db: txn,
            rawText: note,
            amount: signedAmount,
            originId: accountId,
            destinationId: destinationId,
          );
        }
      }

      // Only commit the clean marker after the complete history was trained.
      await txn.insert('app_settings', {
        'key': 'categorization_model_version',
        'value': '2',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_settings', {
        'key': 'categorization_history_dirty',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
