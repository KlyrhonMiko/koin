import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:intl/intl.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Accounts'),
      ),

      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
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
                    child: Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.textLightColor(context).withValues(alpha: 0.4)),
                  ),
                  const Gap(20),
                  Text(
                    'No accounts yet',
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Gap(6),
                  Text(
                    'Create an account to start tracking',
                    style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index == accounts.length) {
                return GestureDetector(
                  onTap: () => _showAddAccountSheet(context, ref),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                        width: 1.5,
                        style: BorderStyle.solid, // Could use a custom painter for dashed, but solid is cleaner for now
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
                  ).animate().fade(delay: (index * 60).ms).slideY(begin: 0.08),
                );
              }
              final account = accounts[index];
              final balance = stats.accountBalances[account.id] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.dividerColor(context)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: account.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
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
                  trailing: Text(
                    NumberFormat.currency(symbol: currency.symbol).format(balance),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ).animate().fade(delay: (index * 60).ms).slideY(begin: 0.08);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    int selectedIcon = Icons.account_balance_wallet.codePoint;
    Color selectedColor = AppTheme.primaryColor(context);

    final colors = [
      AppTheme.primaryColor(context),
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(20),
              const Text(
                'Add Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Gap(24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const Gap(16),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(
                  labelText: 'Initial Balance',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const Gap(20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colors.map((c) {
                  final isSelected = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
              const Gap(28),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppTheme.primaryGradient(context),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        final newAccount = Account(
                          id: const Uuid().v4(),
                          name: nameController.text,
                          initialBalance: double.tryParse(balanceController.text) ?? 0.0,
                          iconCodePoint: selectedIcon,
                          colorHex: '#${selectedColor.toARGB32().toRadixString(16).substring(2)}',
                        );
                        ref.read(accountProvider.notifier).addAccount(newAccount);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
