import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/categorization/intent_classifier.dart';

class ParsedTransactionData {
  final double? amount;
  final TransactionType type;
  final TransactionCategory? category;
  final Account? account;
  final Account? toAccount;
  final String note;

  ParsedTransactionData({
    this.amount,
    required this.type,
    this.category,
    this.account,
    this.toAccount,
    required this.note,
  });

  ParsedTransactionData copyWith({
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    Account? account,
    Account? toAccount,
    String? note,
  }) {
    return ParsedTransactionData(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      account: account ?? this.account,
      toAccount: toAccount ?? this.toAccount,
      note: note ?? this.note,
    );
  }
}

class VoiceCommandParser {
  static ParsedTransactionData parse(
    String text,
    List<TransactionCategory> categories,
    List<AppTransaction> pastTransactions, [
    List<Account> accounts = const [],
  ]) {
    text = text.toLowerCase();

    // Parse Amount
    double? amount;
    // Look for numbers including decimals and optional comma thousands separators
    final amountMatch = RegExp(
      r'(?:php|usd|\$|₱)?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s?(k|m|thousand|million)?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (amountMatch != null) {
      final cleanAmountString = amountMatch.group(1)!.replaceAll(',', '');
      amount = double.tryParse(cleanAmountString);
      final multiplier = amountMatch.group(2)?.toLowerCase().trim();
      if (amount != null && (multiplier == 'k' || multiplier == 'thousand')) {
        amount *= 1000;
      } else if (amount != null &&
          (multiplier == 'm' || multiplier == 'million')) {
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

    // Parse Account(s)
    Account? matchedAccount;
    Account? secondMatchedAccount;
    String? accountNameToRemove;
    String? secondAccountNameToRemove;

    // Sort accounts by length descending to match longer names first ("GCash" before "Cash")
    final sortedAccounts = List<Account>.from(accounts)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (var acc in sortedAccounts) {
      final nameLower = acc.name.toLowerCase();
      // Match whole words to prevent "Cash" matching inside "GCash"
      final regex = RegExp(r'\b' + RegExp.escape(nameLower) + r'\b');
      if (regex.hasMatch(text)) {
        if (matchedAccount == null) {
          matchedAccount = acc;
          accountNameToRemove = nameLower;
        } else if (acc.id != matchedAccount.id) {
          secondMatchedAccount = acc;
          secondAccountNameToRemove = nameLower;
          break;
        }
      }
    }

    // Default to "Cash" if no account was specifically mentioned
    if (matchedAccount == null) {
      for (var acc in accounts) {
        if (acc.name.toLowerCase() == 'cash') {
          matchedAccount = acc;
          break;
        }
      }
    }

    // Heuristic: If it's a transfer and we found two accounts, determine from/to
    // Usually "from Account A to Account B"
    if (type == TransactionType.transfer &&
        matchedAccount != null &&
        secondMatchedAccount != null) {
      final firstIdx = text.indexOf(accountNameToRemove!);
      final secondIdx = text.indexOf(secondAccountNameToRemove!);

      if (secondIdx < firstIdx) {
        // Swap them if the second one appears first in the text
        final temp = matchedAccount;
        matchedAccount = secondMatchedAccount;
        secondMatchedAccount = temp;

        final tempName = accountNameToRemove;
        accountNameToRemove = secondAccountNameToRemove;
        secondAccountNameToRemove = tempName;
      }
    }

    // Refine Note using intent classifier
    String refinedNote = IntentClassifier.extractCleanNote(
      text,
      amountMatch?.group(0),
      accountNameToRemove,
    );
    if (secondAccountNameToRemove != null) {
      refinedNote = IntentClassifier.extractCleanNote(
        refinedNote,
        null, // amount already removed
        secondAccountNameToRemove,
      );
    }

    if (refinedNote.isEmpty && matchedCategory != null) {
      refinedNote = matchedCategory.name;
    }

    return ParsedTransactionData(
      amount: amount,
      type: type,
      category: matchedCategory,
      account: matchedAccount,
      toAccount: secondMatchedAccount,
      note: refinedNote,
    );
  }
}
