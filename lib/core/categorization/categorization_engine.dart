import 'dart:convert';
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
  final bool canAutoApply;

  CategorizationResult({
    required this.originId,
    required this.destinationId,
    required this.type,
    required this.confidence,
    this.isExactMatch = false,
    this.canAutoApply = false,
  });
}

class CategorizationEngine {
  final DatabaseHelper _dbHelper;
  final Uuid _uuid = const Uuid();

  CategorizationEngine({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // Phase 2: Sanitization & Tokenization

  List<String> _tokenize(String rawText) {
    // Preserve Unicode letters, marks, digits, and word boundaries.
    final sanitized = _sanitize(rawText);

    // Split into isolated words
    final words = sanitized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Filter common stop words; keep short merchant names such as SM.
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
    return words.where((w) => !stopWords.contains(w)).toSet().toList();
  }

  String _sanitize(String rawText) {
    return rawText
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true), ' ')
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
    bool allowAmountBasedTransfer = false,
    TransactionType? requestedType,
  }) async {
    await bootstrapFromHistory();
    final sanitizedString = _sanitize(rawText);
    final sign = amount >= 0 ? 1 : -1;
    final tokens = _tokenize(rawText);

    // Step 1: The Exact Match Layer
    final exactMatch = await _checkExactMatch(
      sanitizedString,
      sign,
      requestedType,
    );
    if (exactMatch != null) {
      return exactMatch;
    }

    // An amount/date coincidence cannot establish transfer intent. Use this
    // account-pairing heuristic only after the caller has selected Transfer.
    // Exact and partial-word history matching remain available for all notes.
    if (allowAmountBasedTransfer &&
        amount != 0 &&
        currentAccountId.isNotEmpty) {
      final internalTransfer = await _checkInternalTransfer(
        amount,
        date,
        currentAccountId,
      );
      if (internalTransfer != null) {
        return internalTransfer;
      }
    }

    // Step 3: The Directional Probability Engine
    if (tokens.isEmpty) return null;
    return await _calculateProbability(
      tokens,
      sign,
      currentAccountId,
      requestedType,
    );
  }

  Future<CategorizationResult?> _checkExactMatch(
    String sanitizedString,
    int sign,
    TransactionType? requestedType,
  ) async {
    if (sanitizedString.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'categorization_rules',
      where: 'search_string = ? AND (type = ? OR type = ?)',
      whereArgs: [
        sanitizedString,
        requestedType?.name ??
            (sign >= 0
                ? TransactionType.income.name
                : TransactionType.expense.name),
        requestedType?.name ?? TransactionType.transfer.name,
      ],
      orderBy: 'confidence DESC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final rule = rows.first;
    return CategorizationResult(
      originId: rule['originId'] as String,
      destinationId: rule['destinationId'] as String,
      type: TransactionType.values.byName(rule['type'] as String),
      confidence: (rule['confidence'] as num).toDouble(),
      canAutoApply: rule['canAutoApply'] == 1,
      isExactMatch: true,
    );
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
        confidence: 0.5, // Amount/date pairing is only a suggestion.
        isExactMatch: false,
      );
    }
    return null;
  }

  Future<CategorizationResult?> _calculateProbability(
    List<String> tokens,
    int sign,
    String currentAccountId,
    TransactionType? requestedType,
  ) async {
    final db = await _dbHelper.database;

    // Filter by Direction: retrieve token counts for the specific sign
    final placeholders = List.filled(tokens.length, '?').join(',');
    final queryArgs = [...tokens, sign];

    var results = await db.query(
      'ml_frequency_dictionary',
      where: 'token IN ($placeholders) AND sign = ?',
      whereArgs: queryArgs,
    );
    if (requestedType != null) {
      final destinations = await db.query(
        requestedType == TransactionType.transfer ? 'accounts' : 'categories',
        columns: ['id'],
        where: requestedType == TransactionType.transfer ? null : 'type = ?',
        whereArgs: requestedType == TransactionType.transfer
            ? null
            : [requestedType.name],
      );
      final allowed = destinations.map((row) => row['id']).toSet();
      results = results
          .where((row) => allowed.contains(row['destinationId']))
          .toList();
    }

    if (results.isEmpty) return null;

    final classCounts = <String, int>{};
    final tokenClassCounts = <String, Map<String, int>>{};
    int totalDocs = 0;

    // Aggregate probabilities against historical data matching the sign
    final classTotalsQuery = await db.rawQuery(
      'SELECT destinationId, SUM(occurrences) as total FROM ml_frequency_dictionary WHERE sign = ? GROUP BY destinationId',
      [sign],
    );

    for (var row in classTotalsQuery) {
      final classKey = row['destinationId'] as String;
      final total = (row['total'] as num).toInt();
      classCounts[classKey] = total;
      totalDocs += total;
    }

    if (totalDocs == 0) return null;
    // Priors count examples, while likelihood denominators count words.
    final documentRows = await db.rawQuery(
      '''
SELECT destinationId, COUNT(*) AS count FROM (
  SELECT CASE WHEN type = 'transfer' THEN toAccountId ELSE categoryId END AS destinationId
  FROM transactions
  WHERE TRIM(COALESCE(title, '')) != ''
    AND CASE WHEN type = 'income' THEN 1 ELSE -1 END = ?
  UNION ALL
  SELECT destinationId FROM categorization_feedback
  WHERE CASE WHEN amount >= 0 THEN 1 ELSE -1 END = ?
) GROUP BY destinationId
''',
      [sign, sign],
    );
    final documentCounts = {
      for (final row in documentRows)
        row['destinationId']: (row['count'] as num).toInt(),
    };
    final documentTotal = documentCounts.values.fold<int>(0, (a, b) => a + b);

    for (var token in tokens) {
      tokenClassCounts[token] = {};
    }

    // A partial note needs shared word evidence, not a full-string match.
    // Unrelated classes with no shared tokens must not dilute confidence in
    // "burger" after learning "cheese burger" as Food.
    final uniqueClasses = results
        .map((row) => row['destinationId'] as String)
        .toSet()
        .toList();

    for (var row in results) {
      final token = row['token'] as String;
      final classKey = row['destinationId'] as String;
      final count = (row['occurrences'] as num).toInt();
      if (tokenClassCounts.containsKey(token)) {
        tokenClassCounts[token]![classKey] =
            (tokenClassCounts[token]![classKey] ?? 0) + count;
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
      double logProb = log(
        (documentCounts[classKey] ?? 1) / max(1, documentTotal),
      );

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
      double lp = log((documentCounts[classKey] ?? 1) / max(1, documentTotal));
      for (var token in tokens) {
        final tc = tokenClassCounts[token]?[classKey] ?? 0;
        lp += log((tc + 1) / (classCounts[classKey]! + vocabSize));
      }
      sumExp += exp(lp - bestScore);
    }

    final posterior = 1.0 / sumExp;
    final matchedCounts = tokens
        .map((token) => tokenClassCounts[token]?[bestClass] ?? 0)
        .where((count) => count > 0)
        .toList();
    final support = matchedCounts.reduce(min);
    final coverage = matchedCounts.length / tokens.length;
    final confidence = posterior * support / (support + 2) * coverage;

    // Ambiguous ranking abstains; automatic application additionally requires
    // repeated evidence, a stronger margin, and sufficient word coverage.
    if (posterior >= 0.70) {
      final originId = currentAccountId;
      final destinationId = bestClass;
      final canAutoApply = support >= 3 && posterior >= 0.9 && coverage >= 0.75;

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
          canAutoApply: false,
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
          canAutoApply: canAutoApply,
        );
      }

      return null;
    }

    return null; // Leave blank for manual review
  }

  // Snapshot matching history when remembering a manual choice. Subsequent
  // conflicting additions/edits expire it; unrelated history does not.
  Map<String, String> _historySnapshot(
    List<Map<String, Object?>> transactions,
    String note,
    TransactionType type,
  ) => {
    for (final tx in transactions)
      if (tx['type'] == type.name &&
          _sanitize(tx['title'] as String? ?? '') == note)
        tx['id'] as String:
            (type == TransactionType.transfer
                    ? tx['toAccountId']
                    : tx['categoryId'])
                as String? ??
            '',
  };

  Future<void> processFeedback({
    required String rawText,
    required double amount,
    required String originId,
    required String destinationId,
  }) async {
    final sanitized = _sanitize(rawText);
    if (sanitized.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final accounts = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [destinationId],
      );
      final type = accounts.isNotEmpty
          ? TransactionType.transfer
          : amount >= 0
          ? TransactionType.income
          : TransactionType.expense;
      final history = await txn.query('transactions');
      await txn.insert('categorization_feedback', {
        'id': '${amount >= 0 ? 1 : -1}|$sanitized',
        'rawText': rawText,
        'amount': amount,
        'originId': originId,
        'destinationId': destinationId,
        'historySnapshot': jsonEncode(
          _historySnapshot(history, sanitized, type),
        ),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_settings', {
        'key': 'categorization_history_dirty',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await bootstrapFromHistory();
  }

  /// Aggregate in memory and batch writes instead of looking up every token.
  /// Exact suggestions read cached evidence rather than rescanning history.
  Future<void> bootstrapFromHistory() async {
    final db = await _dbHelper.database;
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
      if (values['categorization_model_version'] == '4' &&
          values['categorization_history_dirty'] != 'true') {
        return;
      }

      final accountIds = (await txn.query(
        'accounts',
        columns: ['id'],
      )).map((row) => row['id']).toSet();
      final categoryTypes = {
        for (final row in await txn.query(
          'categories',
          columns: ['id', 'type'],
        ))
          row['id']: row['type'],
      };
      TransactionType? destinationType(String id, double amount) {
        if (accountIds.contains(id)) return TransactionType.transfer;
        final type = amount >= 0
            ? TransactionType.income
            : TransactionType.expense;
        return categoryTypes[id] == type.name ? type : null;
      }

      final transactions = await txn.query(
        'transactions',
        orderBy: 'date ASC, id ASC',
      );
      final historyByNoteType = <String, Map<String, String>>{};
      for (final tx in transactions) {
        final key = jsonEncode([
          _sanitize(tx['title'] as String? ?? ''),
          tx['type'],
        ]);
        final snapshot = historyByNoteType.putIfAbsent(key, () => {});
        snapshot[tx['id'] as String] =
            (tx['type'] == TransactionType.transfer.name
                    ? tx['toAccountId']
                    : tx['categoryId'])
                as String? ??
            '';
      }
      final groups = <String, _ExactGroup>{};
      final frequencies = <String, Map<String, Object?>>{};

      void train(
        String text,
        double amount,
        String originId,
        String destinationId,
        TransactionType type, {
        bool remembered = false,
      }) {
        final note = _sanitize(text);
        if (note.isEmpty) return;
        final groupKey = jsonEncode([note, type.name]);
        final group = groups.putIfAbsent(
          groupKey,
          () => _ExactGroup(note, type),
        );
        group.add(originId, destinationId, remembered: remembered);
        final sign = amount >= 0 ? 1 : -1;
        for (final token in _tokenize(text)) {
          final key = jsonEncode([token, originId, destinationId, sign]);
          final row = frequencies.putIfAbsent(
            key,
            () => {
              'id': _uuid.v4(),
              'token': token,
              'originId': originId,
              'destinationId': destinationId,
              'sign': sign,
              'occurrences': 0,
            },
          );
          row['occurrences'] = (row['occurrences'] as int) + 1;
        }
      }

      for (final tx in transactions) {
        final originId = tx['accountId'] as String?;
        if (!accountIds.contains(originId)) continue;
        final type = TransactionType.values.byName(tx['type'] as String);
        final destinationId =
            (type == TransactionType.transfer
                    ? tx['toAccountId']
                    : tx['categoryId'])
                as String?;
        if (destinationId == null) continue;
        final amount = (tx['amount'] as num).toDouble().abs();
        final signed = type == TransactionType.income
            ? (amount == 0 ? 1.0 : amount)
            : -(amount == 0 ? 1.0 : amount);
        if (destinationType(destinationId, signed) != type) continue;
        train(
          tx['title'] as String? ?? '',
          signed,
          originId!,
          destinationId,
          type,
        );
      }

      final expiredFeedback = <String>[];
      for (final sample in await txn.query(
        'categorization_feedback',
        orderBy: 'id',
      )) {
        final destinationId = sample['destinationId'] as String;
        final amount = (sample['amount'] as num).toDouble();
        final type = destinationType(destinationId, amount);
        if (type == null) {
          expiredFeedback.add(sample['id'] as String);
          continue;
        }
        final snapshotJson = sample['historySnapshot'] as String?;
        final current =
            historyByNoteType[jsonEncode([
              _sanitize(sample['rawText'] as String),
              type.name,
            ])] ??
            <String, String>{};
        var remembered = false;
        if (snapshotJson != null) {
          final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
          final expired =
              snapshot.keys.any((id) => !current.containsKey(id)) ||
              current.entries.any(
                (entry) =>
                    entry.value != destinationId &&
                    snapshot[entry.key] != entry.value,
              );
          if (expired) {
            expiredFeedback.add(sample['id'] as String);
            continue;
          }
          remembered = true;
        }
        // Legacy feedback has no provenance: retain it as ordinary evidence.
        train(
          sample['rawText'] as String,
          amount,
          sample['originId'] as String,
          destinationId,
          type,
          remembered: remembered,
        );
      }

      final batch = txn.batch();
      batch.delete('categorization_rules');
      batch.delete('ml_frequency_dictionary');
      for (final id in expiredFeedback) {
        batch.delete(
          'categorization_feedback',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      for (final group in groups.values) {
        batch.insert('categorization_rules', group.toRow(_uuid.v4()));
      }
      for (final row in frequencies.values) {
        batch.insert('ml_frequency_dictionary', row);
      }
      batch.insert('app_settings', {
        'key': 'categorization_model_version',
        'value': '4',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('app_settings', {
        'key': 'categorization_history_dirty',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }
}

class _ExactGroup {
  final String note;
  final TransactionType type;
  final Map<String, int> counts = {};
  final Map<String, String> origins = {};
  String? rememberedDestination;
  final lastSeen = <String, int>{};
  int _sequence = 0;

  _ExactGroup(this.note, this.type);

  void add(String origin, String destination, {required bool remembered}) {
    counts[destination] = (counts[destination] ?? 0) + 1;
    origins[destination] = origin;
    lastSeen[destination] = _sequence++;
    if (remembered) rememberedDestination = destination;
  }

  Map<String, Object?> toRow(String id) {
    final highest = counts.values.reduce(max);
    // Recency breaks ties only; one recent outlier cannot hide a majority.
    final destination =
        rememberedDestination ??
        counts.keys
            .where((key) => counts[key] == highest)
            .reduce((a, b) => lastSeen[a]! > lastSeen[b]! ? a : b);
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final supporting = counts[destination]!;
    final remembered = rememberedDestination != null;
    return {
      'id': id,
      'search_string': note,
      'type': type.name,
      'originId': origins[destination]!,
      'destinationId': destination,
      'confidence': remembered ? 0.95 : (supporting + 1) / (total + 2),
      'canAutoApply':
          type != TransactionType.transfer &&
              (remembered || (supporting >= 3 && supporting / total >= 0.9))
          ? 1
          : 0,
    };
  }
}
