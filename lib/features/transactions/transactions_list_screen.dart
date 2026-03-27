import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accountsAsync = ref.watch(accountProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return RefreshIndicator(
      onRefresh: () {
        HapticService.light();
        return ref.read(transactionProvider.notifier).loadTransactions();
      },
      color: AppTheme.primaryColor(context),
      backgroundColor: AppTheme.surfaceColor(context),
      child: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: const Alignment(0, -0.3), // Shifted up further from -0.2 to -0.3
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Keep column compact
                      children: [
                        Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(Icons.receipt_long_rounded, size: 56, color: AppTheme.primaryColor(context).withValues(alpha: 0.6)),
                        ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
                        const SizedBox(height: 24),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                        ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms).fadeIn(),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first transaction to see it here',
                          style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 14),
                        ).animate().slideY(begin: 0.2, delay: 400.ms, duration: 400.ms).fadeIn(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Group transactions by date
          final grouped = <String, List<AppTransaction>>{};
          for (final tx in transactions) {
            final key = DateFormat.yMMMd().format(tx.date);
            grouped.putIfAbsent(key, () => []).add(tx);
          }
          final dateKeys = grouped.keys.toList();

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: dateKeys.length,
            itemBuilder: (context, sectionIndex) {
              final dateKey = dateKeys[sectionIndex];
              final txList = grouped[dateKey]!;

              double dailyTotal = 0;
              for (var tx in txList) {
                if (tx.type == TransactionType.income) {
                  dailyTotal += tx.amount;
                } else if (tx.type == TransactionType.expense) {
                  dailyTotal -= tx.amount;
                }
              }

              String formattedTotal = NumberFormat.currency(symbol: currency.symbol).format(dailyTotal.abs());
              if (dailyTotal > 0) formattedTotal = '+$formattedTotal';
              if (dailyTotal < 0) formattedTotal = '-$formattedTotal';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sectionIndex > 0) const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.dividerColor(context)),
                          ),
                          child: Text(
                            dateKey,
                            style: TextStyle(
                              color: AppTheme.textLightColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (dailyTotal != 0)
                          Text(
                            formattedTotal,
                            style: TextStyle(
                              color: dailyTotal > 0 ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...txList.asMap().entries.map((entry) {
                    final tx = entry.value;
                    final isIncome = tx.type == TransactionType.income;
                    final isTransfer = tx.type == TransactionType.transfer;

                    final color = isTransfer
                        ? AppTheme.transferColor(context)
                        : (isIncome ? AppTheme.incomeColor(context) : AppTheme.expenseColor(context));

                    final icon = isTransfer
                        ? Icons.swap_horiz_rounded
                        : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);

                    final categoryName = categories
                        .where((c) => c.id == tx.categoryId)
                        .map((c) => c.name)
                        .firstOrNull ?? 'Others';

                    final accountName = accountsAsync.when(
                      data: (accounts) => accounts.where((a) => a.id == tx.accountId).map((a) => a.name).firstOrNull ?? 'Account',
                      loading: () => '...',
                      error: (error, stack) => 'Error',
                    );

                    final displayTitle = tx.note.isEmpty ? categoryName : tx.note;
                    final displaySubtitle = tx.note.isEmpty ? accountName : '$categoryName • $accountName';

                    return Dismissible(
                      key: Key(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
                      ),
                      onDismissed: (_) {
                        ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                      },
                      confirmDismiss: (direction) async {
                        HapticService.medium();
                        final result = await ConfirmationSheet.show(
                          context: context,
                          title: 'Delete Transaction?',
                          description: 'This transaction will be permanently removed. This action cannot be undone.',
                          confirmLabel: 'Delete',
                          confirmColor: AppTheme.errorColor(context),
                          icon: Icons.delete_forever_rounded,
                          isDanger: true,
                        );
                        return result ?? false;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.5)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            HapticService.light();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTransactionScreen(editingTransaction: tx),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              displaySubtitle,
                              style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isTransfer
                                  ? NumberFormat.currency(symbol: currency.symbol).format(tx.amount)
                                  : '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: currency.symbol).format(tx.amount)}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.jm().format(tx.date),
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fade(delay: (entry.key * 40).ms).slideX(begin: 0.05);
                  }),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
