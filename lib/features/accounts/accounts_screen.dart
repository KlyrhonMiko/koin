import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/premium_confirmation_sheet.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/widgets/account_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('My Accounts'),
      ),

      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: const Alignment(0, -0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                            child: Icon(Icons.account_balance_wallet_rounded, size: 56, color: AppTheme.primaryColor(context).withValues(alpha: 0.6)),
                          ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
                          const SizedBox(height: 24),
                          Text(
                            'No accounts yet',
                            style: TextStyle(color: AppTheme.textColor(context), fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                          ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms).fadeIn(),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first account to see it here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 14),
                          ).animate().slideY(begin: 0.2, delay: 400.ms, duration: 400.ms).fadeIn(),
                          const SizedBox(height: 36),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: AppTheme.primaryGradient(context),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => AccountSheet.show(context, ref),
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                label: const Text('Add Your First Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ).animate().slideY(begin: 0.2, delay: 500.ms, duration: 400.ms).fadeIn(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index == accounts.length) {
                return _buildAddAccountButton(context, ref, delay: (index * 60).ms);
              }
              final account = accounts[index];
              final balance = stats.accountBalances[account.id] ?? 0;
              return Dismissible(
                key: Key(account.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Icon(Icons.delete_rounded, color: AppTheme.errorColor(context)),
                ),
                confirmDismiss: (direction) async {
                  final confirmed = await PremiumConfirmationSheet.show(
                    context: context,
                    title: 'Delete Account?',
                    description: 'All transactions associated with this account will be unlinked. This cannot be undone.',
                    confirmLabel: 'Delete',
                    confirmColor: AppTheme.errorColor(context),
                    icon: Icons.delete_forever_rounded,
                    isDanger: true,
                  );
                  return confirmed ?? false;
                },
                onDismissed: (_) {
                  ref.read(accountProvider.notifier).deleteAccount(account.id);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dividerColor(context)),
                  ),
                  child: ListTile(
                    onTap: () => AccountSheet.show(context, ref, account: account),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: account.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        IconUtils.getIcon(account.iconCodePoint),
                        color: account.color,
                        size: 22,
                      ),
                    ),
                    title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Initial: ${currency.symbol}${account.initialBalance.toStringAsFixed(2)}',
                        style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: currency.symbol).format(balance),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        if (account.excludeFromTotal)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXCLUDED',
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ).animate().fade(delay: (index * 60).ms).slideX(begin: 0.05);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context, WidgetRef ref, {Duration? delay}) {
    return GestureDetector(
      onTap: () => AccountSheet.show(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor(context),
                size: 28,
              ),
            ),
            const Gap(12),
            Text(
              'Add New Account',
              style: TextStyle(
                color: AppTheme.primaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ).animate().fade(delay: delay).slideY(begin: 0.08, delay: delay),
    );
  }
}
