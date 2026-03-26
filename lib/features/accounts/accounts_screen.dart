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
import 'package:koin/core/widgets/premium_confirmation_sheet.dart';
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
                                onPressed: () => _showAddAccountSheet(context, ref),
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
                    onTap: () => _showAccountSheet(context, ref, account: account),
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

  void _showAccountSheet(BuildContext context, WidgetRef ref, {Account? account}) {
    final isEditing = account != null;
    final nameController = TextEditingController(text: account?.name);
    final balanceController = TextEditingController(
      text: isEditing ? account.initialBalance.toString() : '',
    );
    int selectedIcon = account?.iconCodePoint ?? Icons.account_balance_wallet_rounded.codePoint;
    Color selectedColor = account?.color ?? AppTheme.primaryColor(context);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Account' : 'Add Account',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  if (isEditing)
                    IconButton(
                      onPressed: () async {
                        final confirmed = await PremiumConfirmationSheet.show(
                          context: context,
                          title: 'Delete Account?',
                          description: 'All transactions associated with this account will be unlinked. This cannot be undone.',
                          confirmLabel: 'Delete',
                          confirmColor: AppTheme.expenseColor(context),
                          icon: Icons.delete_forever_rounded,
                          isDanger: true,
                        );
                        if (confirmed == true && context.mounted) {
                          ref.read(accountProvider.notifier).deleteAccount(account.id);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                ],
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
                child: Text('Icon', style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const Gap(12),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Icons.account_balance_wallet_rounded,
                    Icons.account_balance_rounded,
                    Icons.savings_rounded,
                    Icons.payments_rounded,
                    Icons.credit_card_rounded,
                    Icons.wallet_rounded,
                    Icons.money_rounded,
                    Icons.currency_exchange_rounded,
                    Icons.trending_up_rounded,
                    Icons.monetization_on_rounded,
                    Icons.paid_rounded,
                    Icons.local_atm_rounded,
                    Icons.request_quote_rounded,
                    Icons.account_tree_rounded,
                    Icons.business_center_rounded,
                    Icons.storefront_rounded,
                    Icons.currency_bitcoin_rounded,
                    Icons.currency_pound_rounded,
                    Icons.currency_yen_rounded,
                    Icons.currency_franc_rounded,
                  ].map((icon) {
                    final isSelected = selectedIcon == icon.codePoint;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon.codePoint),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor.withValues(alpha: 0.1) : AppTheme.dividerColor(context).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? selectedColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? selectedColor : AppTheme.textLightColor(context).withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Gap(20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colors.map((c) {
                  final isSelected = selectedColor.value == c.value;
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
                        final updatedAccount = Account(
                          id: isEditing ? account.id : const Uuid().v4(),
                          name: nameController.text,
                          initialBalance: double.tryParse(balanceController.text) ?? 0.0,
                          iconCodePoint: selectedIcon,
                          colorHex: '#${selectedColor.toARGB32().toRadixString(16).substring(2)}',
                        );
                        
                        if (isEditing) {
                          ref.read(accountProvider.notifier).updateAccount(updatedAccount);
                        } else {
                          ref.read(accountProvider.notifier).addAccount(updatedAccount);
                        }
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isEditing ? 'Update Account' : 'Create Account',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    _showAccountSheet(context, ref);
  }

  Widget _buildAddAccountButton(BuildContext context, WidgetRef ref, {Duration? delay}) {
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
