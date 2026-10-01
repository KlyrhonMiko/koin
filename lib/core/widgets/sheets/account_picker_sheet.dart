import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import '../cards/account_item.dart';
import 'select_sheet.dart';

/// Deep Account Picker Module: Encapsulates account fetching, balance resolution,
/// currency formatting, and privacy toggling behind a single method call.
Future<String?> showAccountPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String? selectedAccountId,
  String title = 'Account',
  String subtitle = 'Choose an account',
  List<Account>? accountsOverride,
  String? excludeAccountId,
  String? emptyMessage,
  bool allowNone = false,
  String noneLabel = 'No Account (Balance only)',
  String noneValue = '',
}) async {
  final rawAccounts =
      accountsOverride ?? (ref.read(accountProvider).value ?? []);
  final accounts = excludeAccountId == null
      ? rawAccounts
      : rawAccounts.where((a) => a.id != excludeAccountId).toList();
  final stats = ref.read(dashboardStatsProvider);
  final currency = ref.read(settingsProvider).currency;
  final totalCount = allowNone ? accounts.length + 1 : accounts.length;

  return await showSelectSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    emptyMessage:
        emptyMessage ??
        (accounts.isEmpty && !allowNone ? 'No accounts available' : null),
    itemCount: totalCount,
    itemBuilder: (sheetContext, index) {
      if (allowNone && index == 0) {
        return SelectSheetItem(
          name: noneLabel,
          accentColor: AppTheme.textLightColor(
            sheetContext,
          ).withValues(alpha: 0.5),
          iconCodePoint: Icons.money_off_rounded.codePoint,
          selected: selectedAccountId == null || selectedAccountId.isEmpty,
          onTap: () => Navigator.pop(sheetContext, noneValue),
        );
      }

      final accIndex = allowNone ? index - 1 : index;
      return Consumer(
        builder: (context, refConsumer, _) {
          final liveAccounts = refConsumer.watch(accountProvider).value ?? [];
          final acc = liveAccounts.firstWhere(
            (a) => a.id == accounts[accIndex].id,
            orElse: () => accounts[accIndex],
          );
          final balance = stats.accountBalances[acc.id] ?? 0.0;

          return AccountItem(
            account: acc,
            balance: balance,
            currencySymbol: currency.symbol,
            isSelected: acc.id == selectedAccountId,
            onTap: () => Navigator.pop(sheetContext, acc.id),
            onPrivateToggle: () {
              final updatedAccount = acc.copyWith(
                excludeFromTotal: !acc.excludeFromTotal,
              );
              refConsumer
                  .read(accountProvider.notifier)
                  .updateAccount(updatedAccount);
            },
          );
        },
      );
    },
  );
}
