import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/widgets/select_sheet.dart';
import 'package:koin/core/widgets/account_item.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/widgets/koin_back_button.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';

class AddEditPlannedPaymentScreen extends ConsumerStatefulWidget {
  final PlannedPayment? payment;

  const AddEditPlannedPaymentScreen({super.key, this.payment});

  @override
  ConsumerState<AddEditPlannedPaymentScreen> createState() =>
      _AddEditPlannedPaymentScreenState();
}

class _AddEditPlannedPaymentScreenState
    extends ConsumerState<AddEditPlannedPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  PaymentFrequency _selectedFrequency = PaymentFrequency.flexible;
  bool _isAutoProcess = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.payment?.title ?? '');
    _amountController = TextEditingController(
      text: widget.payment?.amount.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(text: widget.payment?.notes ?? '');
    if (widget.payment != null) {
      _selectedType = widget.payment!.type;
      _selectedCategoryId = widget.payment!.categoryId;
      _selectedAccountId = widget.payment!.accountId;
      _startDate = widget.payment!.startDate;
      _endDate = widget.payment!.endDate;
      _selectedFrequency = widget.payment!.frequency;
      _isAutoProcess = widget.payment!.isAutoProcess;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      KoinSnackBar.error(
        context,
        'Category required',
        subtitle: 'Please select a category',
      );
      return;
    }

    if (_selectedAccountId == null) {
      KoinSnackBar.error(
        context,
        'Account required',
        subtitle: 'Please select a payment account',
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      KoinSnackBar.error(
        context,
        'Name required',
        subtitle: 'Please provide a name for this payment',
      );
      return;
    }

    HapticService.light();

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    // Calculate next date based on frequency and start date
    DateTime nextDate = _startDate;
    final now = DateTime.now();
    if (_selectedFrequency != PaymentFrequency.flexible) {
      while (nextDate.isBefore(now)) {
        switch (_selectedFrequency) {
          case PaymentFrequency.daily:
            nextDate = nextDate.add(const Duration(days: 1));
            break;
          case PaymentFrequency.weekly:
            nextDate = nextDate.add(const Duration(days: 7));
            break;
          case PaymentFrequency.biWeekly:
            nextDate = nextDate.add(const Duration(days: 14));
            break;
          case PaymentFrequency.monthly:
            nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
            break;
          case PaymentFrequency.quarterly:
            nextDate = DateTime(nextDate.year, nextDate.month + 3, nextDate.day);
            break;
          case PaymentFrequency.yearly:
            nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
            break;
          case PaymentFrequency.flexible:
            break;
        }
      }
    }

    final newPayment = PlannedPayment(
      id: widget.payment?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId!,
      startDate: _startDate,
      endDate: _endDate,
      nextDate: nextDate,
      frequency: _selectedFrequency,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isAutoProcess: _isAutoProcess,
    );

    if (widget.payment == null) {
      await ref
          .read(plannedPaymentProvider.notifier)
          .addPlannedPayment(newPayment);
    } else {
      await ref
          .read(plannedPaymentProvider.notifier)
          .updatePlannedPayment(newPayment);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Subscription?',
      description:
          'Are you sure you want to delete this subscription? This action cannot be undone.',
      confirmLabel: 'Delete Subscription',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_outline_rounded,
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      await ref
          .read(plannedPaymentProvider.notifier)
          .deletePlannedPayment(widget.payment!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildSelectionRow(
    BuildContext context, {
    required IconData fallbackIcon,
    required String label,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    String? selectedLogoAsset,
    required String placeholder,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final hasSelection =
        selectedName != null &&
        selectedColor != null &&
        selectedIconCodePoint != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticService.light();
            final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
            FocusManager.instance.primaryFocus?.unfocus();
            if (hadFocus) {
              await Future.delayed(const Duration(milliseconds: 150));
            }
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Builder(builder: (context) {

                if (hasSelection && selectedLogoAsset != null && selectedLogoAsset.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      selectedLogoAsset,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  );
                }

                  return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? selectedColor.withValues(alpha: 0.12)
                        : AppTheme.surfaceLightColor(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasSelection
                        ? IconUtils.getIcon(selectedIconCodePoint)
                        : fallbackIcon,
                    size: 17,
                    color: hasSelection
                        ? selectedColor
                        : AppTheme.textLightColor(context),
                  ),
                );

                }),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.65),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        hasSelection ? selectedName : placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasSelection
                              ? AppTheme.textColor(context)
                              : AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const Gap(8), trailing],
                const Gap(4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLightColor(context),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: () async {
        final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
        FocusManager.instance.primaryFocus?.unfocus();
        if (hadFocus) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const Gap(6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              DateFormat.yMMMd().format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final settings = ref.read(settingsProvider);
    final currency = settings.currency;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Gap(topPadding + 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const KoinBackButton(),
                const Spacer(),
                if (widget.payment != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.expenseColor(context),
                      size: 24,
                    ),
                    onPressed: _showDeleteConfirmation,
                  ),
              ],
            ),
          ),
          const Gap(8),

          // Subscription Name Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _titleController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: 'Name your subscription',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const Gap(4),

          // Amount Input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${currency.symbol} ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
              IntrinsicWidth(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: _amountController.text.isEmpty
                        ? primaryColor.withValues(alpha: 0.35)
                        : primaryColor,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      color: primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          // Little subtle animated underline
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _amountController.text.isNotEmpty ? 60 : 40,
            height: 3,
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: primaryColor.withValues(
                alpha: _amountController.text.isNotEmpty ? 0.35 : 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryPicker(
    BuildContext context,
    List<TransactionCategory> categories,
  ) async {
    final filteredCategories = categories
        .where((c) => c.type == _selectedType)
        .toList();

    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: 'Category',
      subtitle: 'Choose a category for this subscription',
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final cat = filteredCategories[index];
        return _PremiumSheetItem(
          name: cat.name,
          accentColor: cat.color,
          iconCodePoint: cat.iconCodePoint,
          selected: cat.id == _selectedCategoryId,
          onTap: () => Navigator.pop(context, cat.id),
        );
      },
    );
    if (id != null && mounted) {
      setState(() => _selectedCategoryId = id);
    }
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final stats = ref.read(dashboardStatsProvider);
    final currency = ref.read(settingsProvider).currency;
    final id = await showSelectSheet<String>(
      context: context,
      title: 'Account',
      subtitle: 'Choose the account for this subscription',
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        return Consumer(
          builder: (context, ref, _) {
            final liveAccounts = ref.watch(accountProvider).value ?? [];
            final acc = liveAccounts.firstWhere(
              (a) => a.id == accounts[index].id,
              orElse: () => accounts[index],
            );
            final balance = stats.accountBalances[acc.id] ?? 0.0;
            return AccountItem(
              account: acc,
              balance: balance,
              currencySymbol: currency.symbol,
              isSelected: acc.id == _selectedAccountId,
              onTap: () => Navigator.pop(context, acc.id),
            );
          },
        );
      },
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id);
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final typeColor = AppTheme.primaryColor(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(sheetContext).top + 12,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(sheetContext),
                  border: Border.all(
                    color: AppTheme.dividerColor(sheetContext),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(10),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(sheetContext),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Gap(10),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppTheme.textColor(sheetContext),
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: AppTheme.textLightColor(sheetContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + bottomInset,
                        ),
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const Gap(8),
                        itemBuilder: (context, index) {
                          return itemBuilder(context, index)
                              .animate()
                              .fadeIn(delay: (index * 40).ms, duration: 250.ms)
                              .slideX(
                                begin: 0.04,
                                duration: 250.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.payment != null;
    final primaryColor = AppTheme.primaryColor(context);
    final categoriesState = ref.watch(categoriesProvider);
    final accountsState = ref.watch(accountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context, primaryColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Repeats Section
                    _buildSectionTitle(context, 'Repeats'),
                    const Gap(12),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: PaymentFrequency.values.length,
                        itemBuilder: (context, index) {
                          final f = PaymentFrequency.values[index];
                          final isSelected = _selectedFrequency == f;
                          return GestureDetector(
                            onTap: () {
                              HapticService.light();
                              setState(() => _selectedFrequency = f);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : AppTheme.surfaceColor(context),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : AppTheme.dividerColor(context),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: primaryColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                f.name[0].toUpperCase() + f.name.substring(1),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textColor(context),
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fade(delay: 50.ms).slideY(begin: 0.1),
                    const Gap(32),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _selectedFrequency != PaymentFrequency.flexible
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeline Section
                    _buildSectionTitle(context, 'Timeline'),
                    const Gap(12),
                    _buildDateSelector(
                      context,
                      label: _selectedFrequency == PaymentFrequency.flexible
                          ? 'Start Date'
                          : 'Next Payment Date',
                      date: _startDate,
                      icon: Icons.calendar_month_rounded,
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(
                                  primary: primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (dt != null) setState(() => _startDate = dt);
                      },
                    ),
                    const Gap(32),
                            ].animate(interval: 40.ms).fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                          )
                        : const SizedBox.shrink(),
                    ),


                    // Details Section
                    _buildSectionTitle(context, 'Details'),
                    const Gap(12),
                    Column(
                      children: [
                        // Category Picker
                        _buildSelectionRow(
                          context,
                          fallbackIcon: Icons.category_rounded,
                          label: 'Category',
                          selectedName: categoriesState.when(
                            data: (categories) => categories
                                .where((c) => c.id == _selectedCategoryId)
                                .firstOrNull
                                ?.name,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          selectedColor: categoriesState.when(
                            data: (categories) => categories
                                .where((c) => c.id == _selectedCategoryId)
                                .firstOrNull
                                ?.color,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          selectedIconCodePoint: categoriesState.when(
                            data: (categories) => categories
                                .where((c) => c.id == _selectedCategoryId)
                                .firstOrNull
                                ?.iconCodePoint,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          placeholder: 'Select Category',
                          onTap: () => categoriesState.whenData(
                            (categories) =>
                                _openCategoryPicker(context, categories),
                          ),
                        ),
                        const Gap(12),
                        // Account Picker
                        _buildSelectionRow(
                          context,
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: 'Payment Account',
                          selectedName: accountsState.when(
                            data: (accounts) => accounts
                                .where((a) => a.id == _selectedAccountId)
                                .firstOrNull
                                ?.name,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          selectedColor: accountsState.when(
                            data: (accounts) => accounts
                                .where((a) => a.id == _selectedAccountId)
                                .firstOrNull
                                ?.color,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          selectedIconCodePoint: accountsState.when(
                            data: (accounts) => accounts
                                .where((a) => a.id == _selectedAccountId)
                                .firstOrNull
                                ?.iconCodePoint,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          selectedLogoAsset: accountsState.when(
                            data: (accounts) => accounts
                                .where((a) => a.id == _selectedAccountId)
                                .firstOrNull
                                ?.logoAsset,
                            loading: () => null,
                            error: (_, stackTrace) => null,
                          ),
                          placeholder: 'Select Account',
                          onTap: () => accountsState.whenData(
                            (accounts) => _openAccountPicker(context, accounts),
                          ),
                        ),
                        const Gap(12),
                        // Auto Process Toggle
                        _buildAutoProcessRow(context, primaryColor),
                        const Gap(12),
                        // Notes field
                        _buildNotesInput(context),
                      ],
                    ).animate().fade(delay: 150.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: PressableScale(
          onTap: _savePayment,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              isEditing ? 'Save Changes' : 'Create Subscription',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildAutoProcessRow(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.light();
            setState(() => _isAutoProcess = !_isAutoProcess);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Process Payment',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.65),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Create transaction automatically',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isAutoProcess,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    HapticService.light();
                    setState(() => _isAutoProcess = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLightColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.sticky_note_2_rounded,
                size: 17,
                color: AppTheme.textLightColor(context),
              ),
            ),
            const Gap(12),
            Expanded(
              child: TextField(
                controller: _notesController,
                onTap: () {
                  HapticService.light();
                },
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Notes (Optional)',
                  hintStyle: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.45),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSheetItem extends StatelessWidget {
  const _PremiumSheetItem({
    required this.name,
    required this.accentColor,
    required this.iconCodePoint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color accentColor;
  final int iconCodePoint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.45)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? primary.withValues(alpha: 0.08)
                : AppTheme.surfaceLightColor(context).withValues(alpha: 0.45),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconUtils.getIcon(iconCodePoint),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 26)
              else
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
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
}
