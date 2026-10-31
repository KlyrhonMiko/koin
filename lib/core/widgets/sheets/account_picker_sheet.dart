import 'package:koin/features/accounts/account_form_screen.dart';

import '../primitives/koin_error_state.dart';

import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/theme.dart';

import '../cards/account_item.dart';
import 'select_sheet.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/haptic_utils.dart';

/// Deep Account Picker Module: Encapsulates account fetching, balance resolution,
/// currency formatting, and privacy toggling behind a single method call.
Future<String?> showAccountPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String? selectedAccountId,
  String title = 'Account',
  String subtitle = 'Choose an account',
  String? excludeAccountId,
  String? emptyMessage,
  bool allowNone = false,
  String noneLabel = 'No Account (Balance only)',
  String noneValue = '',
  bool useSpendableBalance = false,
  Map<String, double>? balancesOverride,
}) async {
  final currency = ref.read(settingsProvider).currency;
  return showSelectSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    itemCount: 0,
    itemBuilder: (_, index) => const SizedBox.shrink(),
    searchable: true,
    optionsBuilder: (sheetContext, query) => Consumer(
      builder: (context, liveRef, _) {
        final state = liveRef.watch(accountProvider);
        final balances = liveRef.watch(dashboardStatsProvider).accountBalances;
        final goals = liveRef.watch(savingsGoalsProvider).value ?? [];
        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, stack) => KoinErrorState(
            message: 'Could not load accounts.',
            onRetry: () => liveRef.invalidate(accountProvider),
          ),
          data: (all) {
            final accounts = all
                .where(
                  (a) =>
                      (!a.isArchived || a.id == selectedAccountId) &&
                      a.id != excludeAccountId,
                )
                .toList();
            final total = accounts.length + (allowNone ? 1 : 0);
            return SelectSheetOptions(
              itemCount: total,
              query: query,
              labelForIndex: (index) => allowNone && index == 0
                  ? noneLabel
                  : accounts[index - (allowNone ? 1 : 0)].name,
              emptyMessage: emptyMessage ?? 'No active accounts available',
              emptyAction: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountFormScreen(),
                  ),
                ),
                icon: const Icon(KoinIcons.plus),
                label: const Text('Create account'),
              ),
              itemBuilder: (context, index) {
                if (allowNone && index == 0) {
                  return SelectSheetItem(
                    name: noneLabel,
                    accentColor: AppTheme.textLightColor(context),
                    selected:
                        selectedAccountId == null || selectedAccountId.isEmpty,
                    onTap: () => Navigator.pop(sheetContext, noneValue),
                  );
                }
                final acc = accounts[index - (allowNone ? 1 : 0)];
                final balance =
                    balancesOverride?[acc.id] ??
                    balances[acc.id] ??
                    acc.initialBalance;
                final savings = goals
                    .where(
                      (g) =>
                          g.linkedAccountId == acc.id &&
                          g.currentAmount > 0 &&
                          (useSpendableBalance || !g.includeInDashboardBalance),
                    )
                    .fold(0.0, (sum, g) => sum + g.currentAmount);
                return AccountItem(
                  account: acc,
                  balance: acc.isCredit
                      ? balance
                      : balance -
                            savings.clamp(0, balance.clamp(0, double.infinity)),
                  savingsAmount: goals
                      .where(
                        (g) =>
                            g.linkedAccountId == acc.id &&
                            g.includeInDashboardBalance &&
                            g.currentAmount > 0,
                      )
                      .fold(0.0, (sum, g) => sum + g.currentAmount),
                  currencySymbol: currency.symbol,
                  currency: currency,
                  isSelected: acc.id == selectedAccountId,
                  onTap: () => Navigator.pop(sheetContext, acc.id),
                  onPrivateToggle: () async {
                    try {
                      await liveRef
                          .read(accountProvider.notifier)
                          .updateAccount(
                            acc.copyWith(
                              excludeFromTotal: !acc.excludeFromTotal,
                            ),
                          );
                      HapticService.selection();
                      if (sheetContext.mounted) {
                        KoinSnackBar.info(
                          sheetContext,
                          acc.excludeFromTotal ? 'Account included in totals' : 'Balance hidden and account excluded from totals',
                        );
                      }
                    } catch (_) {
                      if (sheetContext.mounted) {
                        KoinSnackBar.error(
                          sheetContext,
                          'Could not update account inclusion',
                          subtitle: 'Try again.',
                        );
                      }
                    }
                  },
                );
              },
            );
          },
        );
      },
    ),
  );
}
