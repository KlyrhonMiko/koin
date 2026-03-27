import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class AccountSheet {
  static void show(BuildContext context, WidgetRef ref, {Account? account}) {
    final isEditing = account != null;
    final nameController = TextEditingController(text: account?.name);
    final balanceController = TextEditingController(
      text: isEditing ? account.initialBalance.toString() : '',
    );
    int selectedIcon = account?.iconCodePoint ?? Icons.account_balance_wallet_rounded.codePoint;
    Color selectedColor = account?.color ?? AppTheme.primaryColor(context);
    bool excludeFromTotal = account?.excludeFromTotal ?? false;

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
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                          HapticService.medium();
                          final confirmed = await ConfirmationSheet.show(
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
                        onTap: () {
                          HapticService.light();
                          setState(() => selectedIcon = icon.codePoint);
                        },
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
                    final isSelected = selectedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        HapticService.light();
                        setState(() => selectedColor = c);
                      },
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
                const Gap(24),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.1)),
                  ),
                  child: SwitchListTile(
                    title: const Text('Exclude from Total Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Hide this account\'s balance from the dashboard total', style: TextStyle(fontSize: 12)),
                    value: excludeFromTotal,
                    onChanged: (value) {
                      HapticService.light();
                      setState(() => excludeFromTotal = value);
                    },
                    activeThumbColor: AppTheme.primaryColor(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
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
                          HapticService.success();
                          final updatedAccount = Account(
                            id: isEditing ? account.id : const Uuid().v4(),
                            name: nameController.text,
                            initialBalance: double.tryParse(balanceController.text) ?? 0.0,
                            iconCodePoint: selectedIcon,
                            colorHex: '#${selectedColor.toARGB32().toRadixString(16).substring(2)}',
                            excludeFromTotal: excludeFromTotal,
                            position: isEditing ? account.position : ref.read(accountProvider).value?.length ?? 0,
                          );

                          if (isEditing) {
                            ref.read(accountProvider.notifier).updateAccount(updatedAccount);
                          } else {
                            ref.read(accountProvider.notifier).addAccount(updatedAccount);
                          }
                          Navigator.pop(context);
                        } else {
                          HapticService.error();
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
      ),
    );
  }
}
