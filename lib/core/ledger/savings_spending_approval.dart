import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Consent is a draft, never a financial write. The ledger rechecks it and
/// commits the corresponding releases in the same SQLite transaction as spending.
class SavingsSpendingApproval {
  const SavingsSpendingApproval({
    required this.accountId,
    required this.debitCents,
    required this.goalCents,
  });

  final String accountId;
  final int debitCents;
  final Map<String, int> goalCents;
}

class SavingsSpendingApprovals {
  final _drafts = <String, SavingsSpendingApproval>{};

  SavingsSpendingApproval? operator [](String id) => _drafts[id];

  void approve(String id, SavingsSpendingApproval approval) =>
      _drafts[id] = approval;

  void clear(String id) => _drafts.remove(id);
}

final savingsSpendingApprovalsProvider = Provider(
  (ref) => SavingsSpendingApprovals(),
);
