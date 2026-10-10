import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

/// A warning only: recording real spending never automatically changes savings.
Future<bool> confirmSavingsSpending({
  required BuildContext context,
  required WidgetRef ref,
  required String accountId,
  required double amount,
  double previousDebit = 0,
  double? balance,
}) async {
  final accounts = ref.read(accountProvider).value ?? [];
  if (accounts.where((a) => a.id == accountId).firstOrNull?.isCredit == true) {
    return true;
  }
  final goals = await ref.read(savingsGoalsProvider.future);
  final linked = goals
      .where((g) => g.linkedAccountId == accountId && g.currentAmount > 0)
      .toList();
  if (linked.isEmpty) return true;
  final actual =
      balance ?? ref.read(dashboardStatsProvider).accountBalances[accountId];
  if (actual == null || !context.mounted) return false;
  final reserved = linked.fold<double>(0, (sum, g) => sum + g.currentAmount);
  final available = actual + previousDebit - reserved;
  if ((amount * 100).round() <= (available * 100).round()) return true;
  final money = NumberFormat.currency(
    symbol: ref.read(settingsProvider).currency.symbol,
  );
  final names = linked.map((g) => g.name).join(', ');
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This uses reserved savings'),
          content: SingleChildScrollView(
            child: Text(
              'Available to spend: ${money.format(available.clamp(0, double.infinity))}.\n\n${money.format(reserved)} is set aside for $names.\n\nYou can cancel and release savings first. If this spending already happened, record it now and review your savings allocation afterward.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Record anyway'),
            ),
          ],
        ),
      ) ??
      false;
}
