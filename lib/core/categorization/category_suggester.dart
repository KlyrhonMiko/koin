import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/categorization/categorization_engine.dart';
import 'package:koin/core/models/models.dart';

/// Context provided by caller when requesting a suggestion.
class SuggestionContext {
  final String text;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String currentAccountId;

  const SuggestionContext({
    required this.text,
    required this.amount,
    required this.type,
    required this.date,
    required this.currentAccountId,
  });

  /// Mathematical signed amount expected by underlying ML frequency tables.
  double get signedAmount {
    final absAmount = amount.abs() == 0.0 ? 1.0 : amount.abs();
    return type == TransactionType.income ? absAmount : -absAmount;
  }
}

/// Resolved suggestion yielded by the suggester seam.
class CategorySuggestion {
  final String? categoryId;
  final String? originAccountId;
  final String? destinationAccountId;
  final TransactionType type;
  final double confidence;
  final bool isExactMatch;

  const CategorySuggestion({
    this.categoryId,
    this.originAccountId,
    this.destinationAccountId,
    required this.type,
    required this.confidence,
    this.isExactMatch = false,
  });

  bool get isTransfer => type == TransactionType.transfer;
}

/// Domain Seam: The interface that callers use to obtain suggestions and record feedback.
abstract class CategorySuggester {
  Future<CategorySuggestion?> suggest(SuggestionContext context);

  Future<void> recordFeedback({
    required String text,
    required double amount,
    required TransactionType type,
    required String originAccountId,
    required String destinationId,
    bool isTransfer = false,
  });

  Future<void> bootstrap();
}

/// Concrete Production Adapter: Delegates to local ML CategorizationEngine.
class HybridMlSuggesterAdapter implements CategorySuggester {
  final CategorizationEngine _engine;

  HybridMlSuggesterAdapter({CategorizationEngine? engine})
    : _engine = engine ?? CategorizationEngine();

  @override
  Future<CategorySuggestion?> suggest(SuggestionContext context) async {
    if (context.text.trim().isEmpty) return null;

    final result = await _engine.categorize(
      rawText: context.text,
      amount: context.signedAmount,
      date: context.date,
      currentAccountId: context.currentAccountId,
    );

    if (result == null) return null;

    if (result.type == TransactionType.transfer) {
      return CategorySuggestion(
        originAccountId: result.originId.isNotEmpty ? result.originId : null,
        destinationAccountId: result.destinationId,
        type: TransactionType.transfer,
        confidence: result.confidence,
        isExactMatch: result.isExactMatch,
      );
    } else {
      return CategorySuggestion(
        categoryId: result.destinationId,
        originAccountId: result.originId.isNotEmpty ? result.originId : null,
        type: result.type,
        confidence: result.confidence,
        isExactMatch: result.isExactMatch,
      );
    }
  }

  @override
  Future<void> recordFeedback({
    required String text,
    required double amount,
    required TransactionType type,
    required String originAccountId,
    required String destinationId,
    bool isTransfer = false,
  }) async {
    final absAmount = amount.abs() == 0.0 ? 1.0 : amount.abs();
    final signedAmount = type == TransactionType.income
        ? absAmount
        : -absAmount;

    await _engine.processFeedback(
      rawText: text,
      amount: signedAmount,
      originId: originAccountId,
      destinationId: destinationId,
    );
  }

  @override
  Future<void> bootstrap() async {
    await _engine.bootstrapFromHistory();
  }
}

/// Test Adapter: Fast in-memory stub for deterministic unit and widget testing.
class TestStubSuggesterAdapter implements CategorySuggester {
  CategorySuggestion? stubbedSuggestion;
  final List<Map<String, dynamic>> recordedFeedback = [];

  TestStubSuggesterAdapter({this.stubbedSuggestion});

  @override
  Future<CategorySuggestion?> suggest(SuggestionContext context) async {
    return stubbedSuggestion;
  }

  @override
  Future<void> recordFeedback({
    required String text,
    required double amount,
    required TransactionType type,
    required String originAccountId,
    required String destinationId,
    bool isTransfer = false,
  }) async {
    recordedFeedback.add({
      'text': text,
      'amount': amount,
      'type': type,
      'originAccountId': originAccountId,
      'destinationId': destinationId,
      'isTransfer': isTransfer,
    });
  }

  @override
  Future<void> bootstrap() async {}
}

/// Riverpod Provider for CategorySuggester seam
final categorySuggesterProvider = Provider<CategorySuggester>((ref) {
  return HybridMlSuggesterAdapter();
});

/// Lifecycle Coordinator: Encapsulates debouncing, cancellation, and execution
/// so UI screens don't duplicate manual Timer handles.
class DebouncedSuggesterCoordinator {
  final CategorySuggester _suggester;
  final Duration debounceDuration;
  Timer? _timer;

  DebouncedSuggesterCoordinator({
    required CategorySuggester suggester,
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : _suggester = suggester;

  void run({
    required SuggestionContext context,
    required void Function(CategorySuggestion suggestion) onSuggested,
  }) {
    _timer?.cancel();
    if (context.text.trim().isEmpty) return;

    _timer = Timer(debounceDuration, () async {
      try {
        final suggestion = await _suggester.suggest(context);
        if (suggestion != null) {
          onSuggested(suggestion);
        }
      } catch (_) {
        // Silently swallow background prediction failures
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}
