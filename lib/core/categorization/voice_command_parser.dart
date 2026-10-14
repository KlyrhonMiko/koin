import 'package:koin/core/models/models.dart';
import 'package:koin/core/categorization/intent_classifier.dart';

const _unsetVoiceField = Object();

class ParsedTransactionData {
  final double? amount;
  final TransactionType type;
  final TransactionCategory? category;
  final Account? account;
  final Account? toAccount;
  final String note;
  final bool isCategoryExplicit;

  ParsedTransactionData({
    this.amount,
    required this.type,
    this.category,
    this.account,
    this.toAccount,
    required this.note,
    this.isCategoryExplicit = false,
  });

  ParsedTransactionData copyWith({
    double? amount,
    TransactionType? type,
    Object? category = _unsetVoiceField,
    Object? account = _unsetVoiceField,
    Object? toAccount = _unsetVoiceField,
    String? note,
    bool? isCategoryExplicit,
  }) {
    return ParsedTransactionData(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: identical(category, _unsetVoiceField)
          ? this.category
          : category as TransactionCategory?,
      account: identical(account, _unsetVoiceField)
          ? this.account
          : account as Account?,
      toAccount: identical(toAccount, _unsetVoiceField)
          ? this.toAccount
          : toAccount as Account?,
      note: note ?? this.note,
      isCategoryExplicit: isCategoryExplicit ?? this.isCategoryExplicit,
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

    // Transfer commands take precedence. "Paid for" is spending; only
    // receiving phrases such as "got paid" establish income.
    TransactionType type = TransactionType.expense;
    if (RegExp(r'\b(?:transfer(?:red)?|sent to)\b').hasMatch(text)) {
      type = TransactionType.transfer;
    } else if (RegExp(
      r'\b(?:received|earned|income)\b|\b(?:got\s+paid|paid\s+me)\b|\bgot\s+(?:php|usd|\$|₱)?\s*\d',
    ).hasMatch(text)) {
      type = TransactionType.income;
    }

    // Only an unambiguous, explicit category name may bypass learned evidence.
    // Inferred intent is handled by CategorySuggester with its usual safeguards.
    final namedCategories = categories.where((cat) {
      if (cat.type != type || cat.name.trim().isEmpty) return false;
      return RegExp(
        r'(^|[^\p{L}\p{M}\p{N}])' +
            RegExp.escape(cat.name.toLowerCase()) +
            r'($|[^\p{L}\p{M}\p{N}])',
        unicode: true,
      ).hasMatch(text);
    }).toList();
    final matchedCategory = namedCategories.length == 1
        ? namedCategories.single
        : null;
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
      isCategoryExplicit: matchedCategory != null,
      account: matchedAccount,
      toAccount: secondMatchedAccount,
      note: refinedNote,
    );
  }
}
