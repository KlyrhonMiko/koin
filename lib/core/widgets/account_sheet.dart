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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AccountSheetContent(ref: ref, account: account),
    );
  }
}

class _AccountSheetContent extends StatefulWidget {
  final WidgetRef ref;
  final Account? account;

  const _AccountSheetContent({
    required this.ref,
    this.account,
  });

  @override
  State<_AccountSheetContent> createState() => _AccountSheetContentState();
}

class _AccountSheetContentState extends State<_AccountSheetContent> {
  late final TextEditingController nameController;
  late final TextEditingController balanceController;
  late int selectedIcon;
  late Color selectedColor;
  late bool excludeFromTotal;
  bool _colorInitialized = false;
  final ScrollController _iconScrollController = ScrollController();
  final ScrollController _colorScrollController = ScrollController();

  final List<IconData> icons = [
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
  ];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.account != null;
    nameController = TextEditingController(text: widget.account?.name);
    balanceController = TextEditingController(
      text: isEditing ? widget.account!.initialBalance.toString() : '',
    );
    selectedIcon = widget.account?.iconCodePoint ?? Icons.account_balance_wallet_rounded.codePoint;
    excludeFromTotal = widget.account?.excludeFromTotal ?? false;

    // We'll initialize selectedColor in didChangeDependencies since it needs context
    
    // Auto-scroll to selected icon and color
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedIcon();
      _scrollToSelectedColor();
    });
  }

  void _scrollToSelectedIcon() {
    final index = icons.indexWhere((icon) => icon.codePoint == selectedIcon);
    if (index != -1 && _iconScrollController.hasClients) {
      final offset = index * 60.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 30).clamp(
        0.0,
        _iconScrollController.position.maxScrollExtent,
      );
      _iconScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToSelectedColor() {
    final index = AppTheme.accentColors.indexWhere((c) => c.toARGB32() == selectedColor.toARGB32());
    if (index != -1 && _colorScrollController.hasClients) {
      // 44px circle + 12px margin = 56px
      final offset = index * 56.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 28).clamp(
        0.0,
        _colorScrollController.position.maxScrollExtent,
      );
      _colorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize selectedColor if not already set (needs context for AppTheme)
    if (!_colorInitialized) {
      if (widget.account != null) {
        selectedColor = widget.account!.color;
      } else {
        selectedColor = AppTheme.primaryColor(context);
      }
      _colorInitialized = true;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    _iconScrollController.dispose();
    _colorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final colors = AppTheme.accentColors;

    return Container(
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
                        widget.ref.read(accountProvider.notifier).deleteAccount(widget.account!.id);
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
              textCapitalization: TextCapitalization.words,
            ),
            const Gap(16),
            TextField(
              controller: balanceController,
              decoration: const InputDecoration(
                labelText: 'Initial Balance',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Gap(20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Icon', style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const Gap(12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                controller: _iconScrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: icons.length,
                itemBuilder: (context, index) {
                  final icon = icons[index];
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
                },
              ),
            ),
            const Gap(20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Color', style: TextStyle(color: AppTheme.textLightColor(context).withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const Gap(12),
            SizedBox(
              height: 70,
              child: ListView.builder(
                controller: _colorScrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final c = colors[index];
                  final isSelected = selectedColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      HapticService.light();
                      setState(() => selectedColor = c);
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                      ),
                    ),
                  );
                },
              ),
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
                        id: isEditing ? widget.account!.id : const Uuid().v4(),
                        name: nameController.text,
                        initialBalance: double.tryParse(balanceController.text) ?? 0.0,
                        iconCodePoint: selectedIcon,
                        colorHex: '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                        excludeFromTotal: excludeFromTotal,
                        position: isEditing ? widget.account!.position : widget.ref.read(accountProvider).value?.length ?? 0,
                      );

                      if (isEditing) {
                        widget.ref.read(accountProvider.notifier).updateAccount(updatedAccount);
                      } else {
                        widget.ref.read(accountProvider.notifier).addAccount(updatedAccount);
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
    );

  }
}
