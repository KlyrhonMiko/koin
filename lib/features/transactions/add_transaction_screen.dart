import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/numpad.dart';
import 'package:koin/features/categories/category_manager_screen.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final AppTransaction? editingTransaction;
  final TransactionType? initialType;

  const AddTransactionScreen({
    super.key,
    this.editingTransaction,
    this.initialType,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteFocusNode = FocusNode();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String _currentExpression = '';

  late AnimationController _colorAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Color _prevColor = const Color(0xFFFF6B6B);
  Color _currentColor = const Color(0xFFFF6B6B);

  bool _initializedColors = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    _noteFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.editingTransaction != null) {
      final tx = widget.editingTransaction!;
      _noteController.text = tx.note;
      if (tx.amount == tx.amount.truncateToDouble()) {
        _amountController.text = tx.amount.toInt().toString();
      } else {
        _amountController.text = tx.amount.toString();
      }
      _currentExpression = _amountController.text;
      _selectedDate = tx.date;
      _selectedType = tx.type;
      _selectedCategoryId = tx.categoryId;
      _selectedAccountId = tx.accountId;
      _selectedToAccountId = tx.toAccountId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedColors) {
      _initializedColors = true;
      final color = _getTypeColor(context);
      _prevColor = color;
      _currentColor = color;
    }
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _colorAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // Save
  // ═══════════════════════════════════════════════════════
  void _saveTransaction() {
    final isTransfer = _selectedType == TransactionType.transfer;

    if (_amountController.text.isEmpty ||
        (!isTransfer && _selectedCategoryId == null) ||
        _selectedAccountId == null ||
        (isTransfer && _selectedToAccountId == null)) {
      HapticService.error();
      _showErrorSnackbar('Please fill all required fields');
      return;
    }

    if (isTransfer && _selectedAccountId == _selectedToAccountId) {
      HapticService.error();
      _showErrorSnackbar('Source and destination must be different');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      HapticService.error();
      _showErrorSnackbar('Enter a valid amount');
      return;
    }

    final newTransaction = AppTransaction(
      id: widget.editingTransaction?.id ?? const Uuid().v4(),
      note: _noteController.text,
      amount: amount,
      date: _selectedDate,
      type: _selectedType,
      categoryId: isTransfer ? 'cat_others' : _selectedCategoryId!,
      accountId: _selectedAccountId!,
      toAccountId: isTransfer ? _selectedToAccountId : null,
    );

    if (widget.editingTransaction != null) {
      ref.read(transactionProvider.notifier).updateTransaction(newTransaction);
    } else {
      ref.read(transactionProvider.notifier).addTransaction(newTransaction);
    }
    HapticService.success();
    Navigator.pop(context);
  }

  void _showErrorSnackbar(String message) {
    KoinSnackBar.error(context, message);
  }

  // ═══════════════════════════════════════════════════════
  // Date picker
  // ═══════════════════════════════════════════════════════
  Future<void> _pickDate() async {
    HapticService.light();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(context),
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor(context),
              onSurface: AppTheme.textColor(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // Time picker
  // ═══════════════════════════════════════════════════════
  Future<void> _pickTime() async {
    HapticService.light();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(context),
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor(context),
              onSurface: AppTheme.textColor(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  Color _getTypeColor(BuildContext context) {
    switch (_selectedType) {
      case TransactionType.expense:
        return AppTheme.expenseColor(context);
      case TransactionType.income:
        return AppTheme.incomeColor(context);
      case TransactionType.transfer:
        return AppTheme.transferColor(context);
    }
  }

  void _onTypeChanged(
    TransactionType newType,
    List<TransactionCategory> categories,
  ) {
    final oldColor = _getTypeColor(context);
    HapticService.selection();
    setState(() {
      _selectedType = newType;
      if (_selectedCategoryId != null) {
        final cat = _categoryById(categories, _selectedCategoryId);
        if (cat != null &&
            cat.type != _selectedType &&
            _selectedType != TransactionType.transfer) {
          _selectedCategoryId = null;
        }
      }
    });
    _prevColor = oldColor;
    _currentColor = _getTypeColor(context);
    _colorAnimController.forward(from: 0);
  }

  int get _typeIndex {
    switch (_selectedType) {
      case TransactionType.expense:
        return 0;
      case TransactionType.income:
        return 1;
      case TransactionType.transfer:
        return 2;
    }
  }

  TransactionCategory? _categoryById(
    List<TransactionCategory> list,
    String? id,
  ) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? _accountById(List<Account> list, String? id) {
    if (id == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final typeColor = _getTypeColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _colorAnimController,
      builder: (context, child) {
        final animatedColor =
            Color.lerp(_prevColor, _currentColor, _colorAnimController.value) ??
            typeColor;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(context),
          body: Column(
            children: [
              _buildHeader(context, animatedColor, currency, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _buildFormSection(context, categories, animatedColor),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                child: MediaQuery.of(context).viewInsets.bottom == 0
                    ? NumPad(
                        key: const ValueKey('numpad'),
                        compact: true,
                        initialValue: _currentExpression,
                        onValueChanged: (expression, result) {
                          setState(() {
                            _currentExpression = expression;
                            _amountController.text = result;
                          });
                        },
                        onDone: () => _saveTransaction(),
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                        width: double.infinity,
                        height: 0,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // Immersive Header
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(
    BuildContext context,
    Color typeColor,
    dynamic currency,
    bool isDark,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;

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
          Gap(topPadding),
          // ── Top bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Back button
                IconButton(
                  onPressed: () {
                    HapticService.light();
                    Navigator.pop(context);
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(
                        context,
                      ).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ),
                const Spacer(),
                // Date & Time chips
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time chip
                    PressableScale(
                      enableHaptic: false,
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(
                            context,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppTheme.textLightColor(context),
                            ),
                            const Gap(5),
                            Text(
                              DateFormat('h:mm a').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(6),
                    // Date chip
                    PressableScale(
                      enableHaptic: false,
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor(
                            context,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppTheme.textLightColor(context),
                            ),
                            const Gap(5),
                            Text(
                              DateFormat('MMM d').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(4),
          // ── Type selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTypeSelector(context, typeColor),
          ),
          const Gap(24),
          // ── Hero amount ──
          _buildHeroAmount(context, currency, typeColor),
          const Gap(24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Type Selector
  // ═══════════════════════════════════════════════════════
  Widget _buildTypeSelector(BuildContext context, Color activeColor) {
    final categories = ref.read(categoriesProvider).value ?? [];
    final types = [
      (
        'Expense',
        TransactionType.expense,
        AppTheme.expenseColor(context),
        Icons.arrow_upward_rounded,
      ),
      (
        'Income',
        TransactionType.income,
        AppTheme.incomeColor(context),
        Icons.arrow_downward_rounded,
      ),
      (
        'Transfer',
        TransactionType.transfer,
        AppTheme.transferColor(context),
        Icons.swap_horiz_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _typeIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: types.map((t) {
                  final isSelected = _selectedType == t.$2;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onTypeChanged(t.$2, categories),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              t.$4,
                              size: 15,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textLightColor(context),
                            ),
                            const Gap(5),
                            Text(
                              t.$1,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textLightColor(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Hero Amount
  // ═══════════════════════════════════════════════════════
  Widget _buildHeroAmount(
    BuildContext context,
    dynamic currency,
    Color typeColor,
  ) {
    final hasAmount =
        _currentExpression.isNotEmpty && _currentExpression != '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Currency label
          Text(
            currency.code,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: typeColor.withValues(alpha: 0.5),
              letterSpacing: 1.5,
            ),
          ),
          const Gap(4),
          // Main amount
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
                  color: typeColor.withValues(alpha: 0.4),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _currentExpression.isEmpty ? '0' : _currentExpression,
                  key: ValueKey(_currentExpression),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: hasAmount
                        ? typeColor
                        : typeColor.withValues(alpha: 0.35),
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          // Animated underline accent
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: hasAmount ? 60 : 40,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: typeColor.withValues(
                    alpha: hasAmount
                        ? 0.35
                        : (0.15 + 0.2 * _pulseAnimation.value),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Form Section
  // ═══════════════════════════════════════════════════════
  Widget _buildFormSection(
    BuildContext context,
    List<TransactionCategory> categories,
    Color typeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Note field ──
        Container(
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
                    controller: _noteController,
                    focusNode: _noteFocusNode,
                    onTap: () {
                      HapticService.light();
                    },
                    onTapOutside: (_) => _noteFocusNode.unfocus(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a note...',
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
        ),

        const Gap(12),

        // ── Category & Account card ──
        Container(
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
          child: Column(
            children: [
              // Category (non-transfer only)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SizeTransition(
                  sizeFactor: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _selectedType != TransactionType.transfer
                    ? Column(
                        key: const ValueKey('cat_section'),
                        children: [
                          _buildSelectionRow(
                            context,
                            fallbackIcon: Icons.category_rounded,
                            label: 'Category',
                            selectedName: _categoryById(
                              categories,
                              _selectedCategoryId,
                            )?.name,
                            selectedColor: _categoryById(
                              categories,
                              _selectedCategoryId,
                            )?.color,
                            selectedIconCodePoint: _categoryById(
                              categories,
                              _selectedCategoryId,
                            )?.iconCodePoint,
                            placeholder: 'Select category',
                            onTap: () =>
                                _openCategoryPicker(context, categories),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLightColor(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                tooltip: 'Manage categories',
                                onPressed: () {
                                  HapticService.light();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CategoryManagerScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: AppTheme.textLightColor(context),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          _buildDivider(context),
                        ],
                      )
                    : const SizedBox.shrink(key: ValueKey('no_cat')),
              ),

              // Account
              Consumer(
                builder: (context, ref, child) {
                  final accountsAsync = ref.watch(accountProvider);

                  return accountsAsync.when(
                    data: (accounts) {
                      if (_selectedAccountId == null && accounts.isNotEmpty) {
                        _selectedAccountId = accounts.first.id;
                      }

                      return Column(
                        children: [
                          _buildSelectionRow(
                            context,
                            fallbackIcon: Icons.account_balance_wallet_rounded,
                            label: _selectedType == TransactionType.transfer
                                ? 'From'
                                : 'Account',
                            selectedName: _accountById(
                              accounts,
                              _selectedAccountId,
                            )?.name,
                            selectedColor: _accountById(
                              accounts,
                              _selectedAccountId,
                            )?.color,
                            selectedIconCodePoint: _accountById(
                              accounts,
                              _selectedAccountId,
                            )?.iconCodePoint,
                            placeholder: 'Select account',
                            onTap: () => _openAccountPicker(
                              context,
                              accounts,
                              title: 'Account',
                              subtitle:
                                  _selectedType == TransactionType.transfer
                                  ? 'Choose where the money leaves from'
                                  : 'Choose the account for this transaction',
                              selectedId: _selectedAccountId,
                              onSelected: (id) =>
                                  setState(() => _selectedAccountId = id),
                            ),
                          ),
                          // To Account (transfer only)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => SizeTransition(
                              sizeFactor: anim,
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                            child: _selectedType == TransactionType.transfer
                                ? Column(
                                    key: const ValueKey('to_acc'),
                                    children: [
                                      _buildDivider(context),
                                      _buildSelectionRow(
                                        context,
                                        fallbackIcon: Icons
                                            .account_balance_wallet_rounded,
                                        label: 'To',
                                        selectedName: _accountById(
                                          accounts,
                                          _selectedToAccountId,
                                        )?.name,
                                        selectedColor: _accountById(
                                          accounts,
                                          _selectedToAccountId,
                                        )?.color,
                                        selectedIconCodePoint: _accountById(
                                          accounts,
                                          _selectedToAccountId,
                                        )?.iconCodePoint,
                                        placeholder: 'Select destination',
                                        onTap: () => _openAccountPicker(
                                          context,
                                          accounts,
                                          title: 'Destination',
                                          subtitle:
                                              'Choose where the money arrives',
                                          selectedId: _selectedToAccountId,
                                          excludeAccountId: _selectedAccountId,
                                          onSelected: (id) => setState(
                                            () => _selectedToAccountId = id,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(key: ValueKey('no_to')),
                          ),
                        ],
                      );
                    },
                    loading: () => Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.primaryColor(context),
                        ),
                      ),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: $err',
                        style: TextStyle(
                          color: AppTheme.errorColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // Selection Row — two-line label + value with icon
  // ═══════════════════════════════════════════════════════
  Widget _buildSelectionRow(
    BuildContext context, {
    required IconData fallbackIcon,
    required String label,
    required String? selectedName,
    required Color? selectedColor,
    required int? selectedIconCodePoint,
    required String placeholder,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final hasSelection =
        selectedName != null &&
        selectedColor != null &&
        selectedIconCodePoint != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
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
              ),
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
                color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Pickers
  // ═══════════════════════════════════════════════════════
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
      subtitle: 'Choose a category for this transaction',
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
    List<Account> accounts, {
    required String title,
    required String subtitle,
    required String? selectedId,
    required void Function(String?) onSelected,
    String? excludeAccountId,
  }) async {
    final filtered = excludeAccountId == null
        ? accounts
        : accounts.where((a) => a.id != excludeAccountId).toList();
    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      itemCount: filtered.length,
      emptyMessage: filtered.isEmpty ? 'No other accounts available' : null,
      itemBuilder: (context, index) {
        final acc = filtered[index];
        return _PremiumSheetItem(
          name: acc.name,
          accentColor: acc.color,
          iconCodePoint: acc.iconCodePoint,
          selected: acc.id == selectedId,
          onTap: () => Navigator.pop(context, acc.id),
        );
      },
    );
    if (id != null && mounted) {
      onSelected(id);
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    String? emptyMessage,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final typeColor = _getTypeColor(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(sheetContext).padding.top + 12,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
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
                    if (emptyMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 24,
                        ),
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textLightColor(sheetContext),
                          ),
                        ),
                      )
                    else
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
                                .fadeIn(
                                  delay: (index * 40).ms,
                                  duration: 250.ms,
                                )
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
}

// ═══════════════════════════════════════════════════════
// Premium Sheet Item
// ═══════════════════════════════════════════════════════
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
