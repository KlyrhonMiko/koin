import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/utils/intent_classifier.dart';

class ParsedTransactionData {
  final double? amount;
  final TransactionType type;
  final TransactionCategory? category;
  final String note;

  ParsedTransactionData({
    this.amount,
    required this.type,
    this.category,
    required this.note,
  });
}

class VoiceCommandParser {
  static ParsedTransactionData parse(
    String text,
    List<TransactionCategory> categories,
    List<AppTransaction> pastTransactions,
  ) {
    text = text.toLowerCase();

    // Parse Amount
    double? amount;
    // Look for numbers including decimals and optional comma thousands separators
    final amountMatch = RegExp(
      r'(?:php|usd|\$|₱)?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)(k|m)?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (amountMatch != null) {
      final cleanAmountString = amountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(cleanAmountString);
      final multiplier = amountMatch.group(2)?.toLowerCase();
      if (amount != null && multiplier == 'k') {
        amount *= 1000;
      } else if (amount != null && multiplier == 'm') {
        amount *= 1000000;
      }
    }

    // Parse Type
    TransactionType type = TransactionType.expense; // default
    if (text.contains('got') ||
        text.contains('received') ||
        text.contains('earned') ||
        text.contains('paid') ||
        text.contains('income')) {
      type = TransactionType.income;
    } else if (text.contains('transferred') ||
        text.contains('transfer') ||
        text.contains('sent to')) {
      type = TransactionType.transfer;
    }

    // Parse Category
    TransactionCategory? matchedCategory;

    // 1. Direct match (e.g. text contains the actual category name)
    for (var cat in categories) {
      if (text.contains(cat.name.toLowerCase())) {
        matchedCategory = cat;
        break;
      }
    }

    // 2. Statistical NLP match & Auto-Learning
    if (matchedCategory == null) {
      String? foundCategoryKey = IntentClassifier.classifyIntent(
        text,
        categories,
        pastTransactions,
      );

      if (foundCategoryKey != null) {
        // Try to find a category that matches this conceptual intent key by name
        for (var cat in categories) {
          if (cat.name.toLowerCase().contains(foundCategoryKey.toLowerCase())) {
            matchedCategory = cat;
            break;
          }
        }
      }
    }

    // Check for "expense/income" explicit keyword that might override
    if (matchedCategory != null && type == TransactionType.expense) {
      type = matchedCategory.type; // Fallback to category default type
    }

    // Refine Note using intent classifier
    String refinedNote = IntentClassifier.extractCleanNote(
      text,
      amountMatch?.group(0),
    );

    return ParsedTransactionData(
      amount: amount,
      type: type,
      category: matchedCategory,
      note: refinedNote,
    );
  }
}
