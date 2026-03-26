import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: SizedBox.shrink(),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textLightColor(context).withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add your first transaction to get started',
                    style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          // Group transactions by date
          final grouped = <String, List<dynamic>>{};
          for (final tx in transactions) {
            final key = DateFormat.yMMMd().format(tx.date);
            grouped.putIfAbsent(key, () => []).add(tx);
          }
          final dateKeys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: dateKeys.length,
            itemBuilder: (context, sectionIndex) {
              final dateKey = dateKeys[sectionIndex];
              final txList = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sectionIndex > 0) const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 4),
                    child: Text(
                      dateKey,
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
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

                    return Dismissible(
                      key: Key(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
                      ),
                      onDismissed: (_) {
                        ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.dividerColor(context)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              DateFormat.jm().format(tx.date),
                              style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          trailing: Text(
                            isTransfer
                              ? NumberFormat.currency(symbol: currency.symbol).format(tx.amount)
                              : '${isIncome ? '+' : '-'}${NumberFormat.currency(symbol: currency.symbol).format(tx.amount)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.5,
                            ),
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
