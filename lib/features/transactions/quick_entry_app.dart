import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';

const quickWindowChannel = MethodChannel('koin/quick_window');

Future<void> _windowCall(
  String method, [
  Map<String, Object>? arguments,
]) async {
  try {
    await quickWindowChannel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    // Allows previews and widget tests outside the Android host.
  } on PlatformException {
    // Resizing must not discard a draft or prevent a completed save.
  }
}

/// Compact startup UI for the independent Android window.
class QuickEntryStartup extends StatefulWidget {
  const QuickEntryStartup({super.key, required this.initialize});
  final Future<Widget> Function() initialize;

  @override
  State<QuickEntryStartup> createState() => _QuickEntryStartupState();
}

class _QuickEntryStartupState extends State<QuickEntryStartup> {
  late Future<Widget> _app;

  @override
  void initState() {
    super.initState();
    _app = widget.initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _app,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (snapshot.hasError) ...[
                  const Text('Could not open quick entry'),
                  TextButton(
                    onPressed: () => setState(() => _app = widget.initialize()),
                    child: const Text('Try again'),
                  ),
                ] else
                  const CircularProgressIndicator(),
                TextButton(
                  onPressed: () => _windowCall('close'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class QuickEntryApp extends ConsumerWidget {
  const QuickEntryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'Koin quick entry',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: _theme(settings.themeColor, false),
      darkTheme: _theme(settings.themeColor, true),
      home: const QuickEntryFlow(),
    );
  }

  ThemeData _theme(Color color, bool dark) {
    final theme = AppTheme.getTheme(color, dark);
    final foreground = color.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(onPrimary: foreground),
      filledButtonTheme: FilledButtonThemeData(
        style: theme.filledButtonTheme.style?.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : foreground,
          ),
        ),
      ),
    );
  }
}

enum _Step {
  action,
  type,
  income,
  amount,
  details,
  review,
  category,
  account,
  destination,
  success,
}

class QuickEntryFlow extends ConsumerStatefulWidget {
  const QuickEntryFlow({super.key});

  @override
  ConsumerState<QuickEntryFlow> createState() => _QuickEntryFlowState();
}

class _QuickEntryFlowState extends ConsumerState<QuickEntryFlow>
    with TickerProviderStateMixin {
  _Step _step = _Step.action;
  _Step _pickerReturnStep = _Step.details;
  TransactionType _type = TransactionType.expense;
  PlannedPayment? _income;
  final _note = TextEditingController();
  final _fee = TextEditingController();
  String _expression = '';
  double _amount = 0;
  String? _categoryId;
  String? _accountId;
  String? _destinationId;
  DateTime _date = DateTime.now();
  bool _feePercentage = false;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  late final AnimationController _sheetOffset;
  late final AnimationController _stepFade;
  late final Animation<double> _stepOpacity;
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  final _errorKey = GlobalKey();
  final _errorFocus = FocusNode();
  final _closeFocus = FocusNode();
  final _contentKey = GlobalKey();
  int? _reportedHeight;
  int? _reportedColor;

  bool get _transfer => _type == TransactionType.transfer;
  String get _typeLabel => switch (_type) {
    TransactionType.income => 'Income',
    TransactionType.expense => 'Expense',
    TransactionType.transfer => 'Transfer',
  };

  @override
  void initState() {
    super.initState();
    _sheetOffset = AnimationController.unbounded(vsync: this);
    _stepFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 1,
    );
    _stepOpacity = _stepFade.drive(CurveTween(curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _resize());
  }

  @override
  void dispose() {
    _sheetOffset.dispose();
    _stepFade.dispose();
    _scroll.dispose();
    _errorFocus.dispose();
    _closeFocus.dispose();
    _note.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _resize() {
    if (!mounted) return;
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final header = _headerKey.currentContext?.findRenderObject();
    if (header is! RenderBox || !header.hasSize) return;
    final height =
        (box.size.height +
                header.size.height +
                MediaQuery.paddingOf(context).bottom)
            .ceil();
    final color =
        (_step == _Step.amount
                ? AppTheme.backgroundColor(context)
                : AppTheme.surfaceColor(context))
            .toARGB32();
    if (height == _reportedHeight && color == _reportedColor) return;
    _reportedHeight = height;
    _reportedColor = color;
    _windowCall('resize', {'height': height, 'backgroundColor': color});
  }

  void _go(_Step step) {
    FocusManager.instance.primaryFocus?.unfocus();
    _sheetOffset.stop();
    _sheetOffset.value = 0;
    setState(() {
      _step = step;
      _error = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _stepFade.value = 1;
    } else {
      _stepFade.forward(from: 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (step == _Step.success) _closeFocus.requestFocus();
    });
  }

  void _showError(String error) {
    setState(() => _error = error);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _errorFocus.requestFocus();
      final target = _errorKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
        );
      }
    });
  }

  void _returnSheet([double velocity = 0]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheetOffset.value = 0;
    } else {
      _sheetOffset.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 400, damping: 40),
          _sheetOffset.value,
          0,
          velocity,
        ),
      );
    }
  }

  void _back() {
    if (_saving) return;
    switch (_step) {
      case _Step.action:
      case _Step.success:
        _windowCall('close');
      case _Step.type:
      case _Step.income:
        _go(_Step.action);
      case _Step.amount:
        _go(_income == null ? _Step.type : _Step.income);
      case _Step.details:
        _go(_Step.amount);
      case _Step.review:
        _go(_income == null ? _Step.details : _Step.amount);
      case _Step.category:
      case _Step.account:
      case _Step.destination:
        _go(_pickerReturnStep);
    }
  }

  void _selectType(TransactionType type) {
    if (_income != null || _type != type) {
      _categoryId = null;
      _destinationId = null;
      _income = null;
    }
    _type = type;
    _go(_Step.amount);
  }

  void _selectIncome(PlannedPayment income) {
    // Returning to the same income keeps the user's amount and account edits.
    if (_income?.id != income.id) {
      _income = income;
      _type = TransactionType.income;
      _amount = income.amount;
      _expression = NumberFormat('0.##').format(income.amount);
      _categoryId = income.categoryId;
      _accountId = income.accountId;
      _destinationId = null;
      _date = DateTime.now();
    }
    _go(_Step.amount);
  }

  void _nextAmount() {
    if (_saving || _saved) return;
    if (!_amount.isFinite || _amount <= 0) {
      _showError('Enter an amount greater than zero');
      return;
    }
    if (_income != null) {
      _save();
    } else {
      _go(_Step.details);
    }
  }

  String? _validateDetails() {
    final accounts = ref.read(accountProvider).value ?? [];
    if (!accounts.any((a) => a.id == _accountId)) return 'Choose an account';
    if (_transfer) {
      if (!accounts.any((a) => a.id == _destinationId)) {
        return 'Choose a receiving account';
      }
      if (_destinationId == _accountId) return 'Choose two different accounts';
      final fee = double.tryParse(_fee.text.isEmpty ? '0' : _fee.text);
      if (fee == null ||
          !fee.isFinite ||
          fee < 0 ||
          (_feePercentage ? _amount * fee / 100 : fee) >= _amount) {
        return 'Enter a valid fee smaller than the amount';
      }
    } else {
      final categories = ref.read(categoriesProvider).value ?? [];
      if (!categories.any((c) => c.id == _categoryId && c.type == _type)) {
        return 'Choose a category';
      }
    }
    return null;
  }

  void _review() {
    final error = _validateDetails();
    if (error != null) {
      _showError(error);
      return;
    }
    _go(_Step.review);
  }

  TransferDraft get _transferDraft => TransferDraft(
    sourceAccountId: _accountId!,
    destinationAccountId: _destinationId!,
    rawAmount: _amount,
    enteredFee: double.tryParse(_fee.text) ?? 0,
    isFeePercentage: _feePercentage,
    note: _note.text.trim(),
    date: _date,
  );

  Future<void> _save() async {
    if (_saving || _saved) return;
    final error = _validateDetails();
    if (error != null) {
      _showError(error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Reload immediately before recording: the main app can be open too.
      final transactions = await ref.read(ledgerProvider).getTransactions();
      final accounts = await ref.read(accountRepositoryProvider).getAccounts();
      final account = accounts.where((a) => a.id == _accountId).firstOrNull;
      if (account == null) throw StateError('Account no longer exists');
      if (_type != TransactionType.income && !account.isCredit) {
        final balances = DashboardStats.calculate(
          accounts: accounts,
          transactions: transactions,
        ).accountBalances;
        if ((balances[account.id] ?? account.initialBalance) < _amount) {
          if (mounted) {
            _showError('Insufficient balance in ${account.name}');
          }
          return;
        }
      }
      if (_income != null) {
        final schedules = await ref
            .read(plannedPaymentRepositoryProvider)
            .getPlannedPayments();
        final current = schedules
            .where(
              (p) => p.id == _income!.id && p.type == TransactionType.income,
            )
            .firstOrNull;
        if (current == null) throw StateError('Income no longer exists');
        await ref
            .read(plannedPaymentProvider.notifier)
            .processOccurrence(
              payment: current,
              amount: _amount,
              accountId: _accountId!,
              categoryId: _categoryId!,
              date: _date,
            );
      } else if (_transfer) {
        final built = _transferDraft.buildTransactions(sourceAccount: account);
        await ref
            .read(transactionProvider.notifier)
            .addTransfer(
              transferTransaction: built.transferTransaction,
              feeTransaction: built.feeTransaction,
            );
      } else {
        await ref
            .read(transactionProvider.notifier)
            .addTransaction(
              AppTransaction(
                id: const Uuid().v4(),
                note: _note.text.trim(),
                amount: _amount,
                date: _date,
                type: _type,
                categoryId: _categoryId!,
                accountId: _accountId!,
              ),
            );
      }
      _saved = true;
      HapticService.success();
      if (mounted) _go(_Step.success);
    } catch (_) {
      if (mounted) {
        _showError('Could not save. Check your selections and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider);
    final categories = ref.watch(categoriesProvider);
    final currency = ref.watch(settingsProvider).currency;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resize());
    final title = switch (_step) {
      _Step.action => 'Quick entry',
      _Step.type => 'Add transaction',
      _Step.income => 'Claim income',
      _Step.amount => _income?.title ?? '$_typeLabel amount',
      _Step.details => 'Details',
      _Step.category => 'Category',
      _Step.account => 'Account',
      _Step.destination => 'Receiving account',
      _Step.success => _income != null ? 'Income claimed' : 'Transaction saved',
      _Step.review =>
        _income != null ? 'Confirm income claim' : 'Confirm transaction',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnimatedBuilder(
        animation: _sheetOffset,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _sheetOffset.value.clamp(0.0, double.infinity)),
          child: child,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Scaffold(
            backgroundColor: _step == _Step.amount
                ? AppTheme.backgroundColor(context)
                : AppTheme.surfaceColor(context),
            body: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: _headerKey,
                    child: GestureDetector(
                      key: const ValueKey('quick-entry-drag-area'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: _saving
                          ? null
                          : (_) {
                              _sheetOffset.stop();
                              if (_sheetOffset.value < 0) {
                                _sheetOffset.value = 0;
                              }
                            },
                      onVerticalDragUpdate: _saving
                          ? null
                          : (details) {
                              final offset = _sheetOffset.value;
                              final delta = details.delta.dy;
                              final friction = delta > 0 && offset > 120
                                  ? 120 / offset
                                  : 1.0;
                              _sheetOffset.value = (offset + delta * friction)
                                  .clamp(0.0, double.infinity);
                            },
                      onVerticalDragEnd: _saving
                          ? null
                          : (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (_sheetOffset.value >= 48 ||
                                  (_sheetOffset.value > 12 && velocity > 650)) {
                                _windowCall('close');
                              } else {
                                _returnSheet(velocity);
                              }
                            },
                      onVerticalDragCancel: _returnSheet,
                      child: Column(
                        children: [
                          const KoinBottomSheetHandle(
                            padding: EdgeInsets.only(top: 12, bottom: 4),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                if (_step != _Step.action &&
                                    _step != _Step.success)
                                  IconButton(
                                    onPressed: _saving ? null : _back,
                                    tooltip: 'Back',
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  )
                                else
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    textAlign: _step == _Step.amount
                                        ? TextAlign.center
                                        : TextAlign.start,
                                    style: const TextStyle(
                                      fontSize: KoinTypography.screenTitle,
                                      fontWeight: KoinTypography.titleWeight,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _windowCall('close'),
                                  tooltip: _step == _Step.success
                                      ? 'Close'
                                      : 'Cancel',
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      key: ValueKey(_step),
                      child: FadeTransition(
                        opacity: _stepOpacity,
                        child: Column(
                          key: _contentKey,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AbsorbPointer(
                              absorbing:
                                  _saving || (_saved && _step != _Step.success),
                              child: Padding(
                                padding: _step == _Step.amount
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                child: switch (_step) {
                                  _Step.action => Column(
                                    children: [
                                      _option(
                                        'Claim income',
                                        'Collect a saved allowance or recurring income',
                                        Icons.payments_outlined,
                                        () => _go(_Step.income),
                                      ),
                                      const Divider(height: 24),
                                      _option(
                                        'Add transaction',
                                        'Record income, expense, or transfer',
                                        Icons.add_rounded,
                                        () => _go(_Step.type),
                                      ),
                                      const Divider(height: 24),
                                      _option(
                                        'Open app',
                                        'Continue in Koin',
                                        Icons.open_in_new_rounded,
                                        () => _windowCall('openApp'),
                                      ),
                                    ],
                                  ),
                                  _Step.type => Column(
                                    children: [
                                      for (final type in TransactionType.values)
                                        _option(
                                          type.name[0].toUpperCase() +
                                              type.name.substring(1),
                                          '',
                                          switch (type) {
                                            TransactionType.income =>
                                              Icons.add_rounded,
                                            TransactionType.expense =>
                                              Icons.remove_rounded,
                                            TransactionType.transfer =>
                                              Icons.swap_horiz_rounded,
                                          },
                                          () => _selectType(type),
                                        ),
                                    ],
                                  ),
                                  _Step.income => _incomes(),
                                  _Step.amount => _amountStep(
                                    accounts,
                                    categories,
                                    currency,
                                  ),
                                  _Step.details => _details(
                                    accounts,
                                    categories,
                                  ),
                                  _Step.success => Semantics(
                                    liveRegion: true,
                                    child: _success(
                                      accounts.value ?? [],
                                      currency,
                                    ),
                                  ),
                                  _Step.category => _categoryChoices(
                                    categories,
                                  ),
                                  _Step.account => _accountChoices(
                                    accounts,
                                    destination: false,
                                  ),
                                  _Step.destination => _accountChoices(
                                    accounts,
                                    destination: true,
                                  ),
                                  _Step.review => _summary(
                                    accounts.value ?? [],
                                    categories.value ?? [],
                                    currency.symbol,
                                  ),
                                },
                              ),
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Focus(
                                  focusNode: _errorFocus,
                                  child: Semantics(
                                    key: _errorKey,
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: AppTheme.errorColor(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_step == _Step.details || _step == _Step.review)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  20,
                                ),
                                child: FilledButton(
                                  onPressed: _saving || _saved
                                      ? null
                                      : (_step == _Step.review
                                            ? _save
                                            : _review),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      _saving
                                          ? 'Saving…'
                                          : _step == _Step.review
                                          ? 'Confirm & save'
                                          : 'Next',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(List<Account> accounts, Currency currency) {
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final destination = accounts
        .where((a) => a.id == _destinationId)
        .firstOrNull;
    final successColor = AppTheme.incomeContentColor(context);
    final amount = NumberFormat.currency(
      symbol: currency.symbol,
    ).format(_amount);
    final summary = _income != null
        ? '${_income!.title} · ${account?.name ?? 'Your account'}'
        : _transfer
        ? '${account?.name ?? 'Account'} → ${destination?.name ?? 'Account'}'
        : '$_typeLabel · ${account?.name ?? 'Your account'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: _income != null
              ? '$amount received into ${account?.name ?? 'your account'}'
              : '$amount recorded successfully. $summary',
          excludeSemantics: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: successColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: KoinTypography.formTitle,
                        fontWeight: KoinTypography.headingWeight,
                        letterSpacing: KoinTypography.headingTracking,
                        color: AppTheme.textColor(context),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: KoinTypography.compact,
                        color: AppTheme.textLightColor(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          focusNode: _closeFocus,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => _windowCall('close'),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _amountStep(
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<TransactionCategory>> categories,
    Currency currency,
  ) {
    final baseColor = switch (_type) {
      TransactionType.income => AppTheme.incomeColor(context),
      TransactionType.expense => AppTheme.expenseColor(context),
      TransactionType.transfer => AppTheme.transferColor(context),
    };
    final color = Theme.of(context).brightness == Brightness.light
        ? switch (_type) {
            TransactionType.income => AppTheme.incomeContentColor(context),
            TransactionType.expense => const Color(0xFFB42332),
            TransactionType.transfer => const Color(0xFF1D4ED8),
          }
        : baseColor;
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(
          currency.code,
          style: TextStyle(
            fontSize: KoinTypography.compact,
            color: AppTheme.textLightColor(context),
            fontWeight: KoinTypography.labelWeight,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currency.symbol} ',
                  style: TextStyle(
                    fontSize: KoinTypography.screenTitle,
                    color: color,
                    fontWeight: KoinTypography.labelWeight,
                  ),
                ),
                Text(
                  _expression.isEmpty ? '0' : _expression,
                  style: TextStyle(
                    fontSize: KoinTypography.inputAmount,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -2,
                    height: KoinTypography.amountHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expression.contains(RegExp(r'[+\-*/]')))
          Text('= ${currency.symbol}${NumberFormat('0.##').format(_amount)}'),
        const SizedBox(height: 12),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 32),
        if (_income != null) ...[
          _claimSelectors(accounts, categories),
          const SizedBox(height: 16),
        ],
        NumPad(
          compact: true,
          initialValue: _expression,
          doneLabel: _saving ? 'Saving…' : 'Next',
          onValueChanged: (expression, result) => setState(() {
            _expression = expression;
            _amount = double.tryParse(result) ?? 0;
          }),
          onDone: _nextAmount,
        ),
      ],
    );
  }

  Widget _claimSelectors(
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<TransactionCategory>> categories,
  ) {
    final account = (accounts.value ?? [])
        .where((a) => a.id == _accountId)
        .firstOrNull;
    final category = (categories.value ?? [])
        .where((c) => c.id == _categoryId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.fieldBorderColor(context)),
        ),
        child: Column(
          children: [
            SelectionTile(
              asCard: false,
              label: 'Category',
              selectedName: category?.name,
              selectedColor: category?.color,
              selectedIconCodePoint: category?.iconCodePoint,
              fallbackIcon: Icons.category_rounded,
              placeholder: 'Select category',
              onTap: _openCategoryPicker,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
              ),
            ),
            SelectionTile(
              asCard: false,
              label: 'Account',
              selectedName: account?.name,
              selectedColor: account?.color,
              selectedIconCodePoint: account?.iconCodePoint,
              selectedLogoAsset: account?.logoAsset,
              fallbackIcon: Icons.account_balance_wallet_rounded,
              placeholder: 'Select account',
              onTap: _openAccountPicker,
            ),
          ],
        ),
      ),
    );
  }

  void _openCategoryPicker() {
    _pickerReturnStep = _step;
    _go(_Step.category);
  }

  void _openAccountPicker({bool destination = false}) {
    _pickerReturnStep = _step;
    _go(destination ? _Step.destination : _Step.account);
  }

  Widget _categoryChoices(AsyncValue<List<TransactionCategory>> categories) =>
      categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(categoriesProvider),
          child: const Text('Could not load categories. Try again'),
        ),
        data: (all) {
          final choices = all.where((c) => c.type == _type).toList();
          if (choices.isEmpty) return const Text('No categories available');
          return Column(
            children: [
              for (final category in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectSheetItem(
                    name: category.name,
                    accentColor: category.color,
                    iconCodePoint: category.iconCodePoint,
                    selected: category.id == _categoryId,
                    onTap: () {
                      _categoryId = category.id;
                      _go(_pickerReturnStep);
                    },
                  ),
                ),
            ],
          );
        },
      );

  Widget _accountChoices(
    AsyncValue<List<Account>> accounts, {
    required bool destination,
  }) {
    final balances = ref.watch(dashboardStatsProvider).accountBalances;
    final currency = ref.watch(settingsProvider).currency;
    return accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(accountProvider),
        child: const Text('Could not load accounts. Try again'),
      ),
      data: (all) {
        final excluded = _transfer
            ? (destination ? _accountId : _destinationId)
            : null;
        final choices = all.where((a) => a.id != excluded).toList();
        if (choices.isEmpty) return const Text('No accounts available');
        return Column(
          children: [
            for (final account in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AccountItem(
                  account: account,
                  animateBalance: false,
                  balance: balances[account.id] ?? account.initialBalance,
                  currencySymbol: currency.symbol,
                  isSelected:
                      account.id == (destination ? _destinationId : _accountId),
                  onTap: () {
                    if (destination) {
                      _destinationId = account.id;
                    } else {
                      _accountId = account.id;
                      if (_transfer) {
                        _fee.text = account.transferFeeAmount == 0
                            ? ''
                            : account.transferFeeAmount.toString();
                        _feePercentage = account.isTransferFeePercentage;
                      }
                    }
                    _go(_pickerReturnStep);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _option(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback tap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 4,
    horizontalTitleGap: 16,
    leading: ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppTheme.primaryColor(context).withValues(alpha: 0.10),
            AppTheme.surfaceColor(context),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.textColor(context), size: 22),
      ),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: KoinTypography.itemTitle,
        fontWeight: KoinTypography.labelWeight,
        letterSpacing: KoinTypography.itemTracking,
      ),
    ),
    subtitle: subtitle.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: KoinTypography.caption,
                color: AppTheme.textLightColor(context),
                height: 1.4,
              ),
            ),
          ),
    trailing: ExcludeSemantics(
      child: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textLightColor(context),
        size: 20,
      ),
    ),
    onTap: tap,
  );

  Widget _incomes() => ref
      .watch(plannedPaymentProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          children: [
            const Text('Could not load your income schedules'),
            TextButton(
              onPressed: () => ref.invalidate(plannedPaymentProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (payments) {
          final incomes = payments
              .where((p) => p.type == TransactionType.income)
              .toList();
          if (incomes.isEmpty) {
            return const Text(
              'No saved recurring income yet. Set up an income in Portfolio → Incomes first.',
            );
          }
          return Column(
            children: [
              for (final income in incomes)
                _option(
                  income.title,
                  income.frequency == PaymentFrequency.flexible
                      ? 'Flexible · Claim whenever received'
                      : 'Recurring income',
                  Icons.payments_outlined,
                  () => _selectIncome(income),
                ),
            ],
          );
        },
      );

  Widget _details(
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<TransactionCategory>> categories,
  ) {
    if (accounts.hasError || categories.hasError) {
      return Column(
        children: [
          const Text('Could not load accounts or categories'),
          TextButton(
            onPressed: () {
              ref.invalidate(accountProvider);
              ref.invalidate(categoriesProvider);
            },
            child: const Text('Try again'),
          ),
        ],
      );
    }
    if (accounts.isLoading || categories.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final account = accounts.value!
        .where((a) => a.id == _accountId)
        .firstOrNull;
    final destination = accounts.value!
        .where((a) => a.id == _destinationId)
        .firstOrNull;
    final category = categories.value!
        .where((c) => c.id == _categoryId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_income == null) ...[
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'What was this for?',
            ),
          ),
          const SizedBox(height: 16),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Claiming ${_income!.title}'),
          ),
        if (!_transfer) ...[
          SelectionTile(
            label: 'Category',
            selectedName: category?.name,
            selectedColor: category?.color,
            selectedIconCodePoint: category?.iconCodePoint,
            fallbackIcon: Icons.category_outlined,
            placeholder: 'Select category',
            onTap: _openCategoryPicker,
          ),
          const SizedBox(height: 12),
        ],
        SelectionTile(
          label: _transfer ? 'From account' : 'Account',
          selectedName: account?.name,
          selectedColor: account?.color,
          selectedIconCodePoint: account?.iconCodePoint,
          selectedLogoAsset: account?.logoAsset,
          fallbackIcon: Icons.account_balance_wallet_outlined,
          placeholder: 'Select account',
          onTap: _openAccountPicker,
        ),
        const SizedBox(height: 12),
        if (_transfer) ...[
          SelectionTile(
            label: 'To account',
            selectedName: destination?.name,
            selectedColor: destination?.color,
            selectedIconCodePoint: destination?.iconCodePoint,
            selectedLogoAsset: destination?.logoAsset,
            fallbackIcon: Icons.account_balance_wallet_outlined,
            placeholder: 'Select receiving account',
            onTap: () => _openAccountPicker(destination: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Transfer fee (optional)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fee is a percentage'),
            value: _feePercentage,
            onChanged: (value) => setState(() => _feePercentage = value),
          ),
        ],
      ],
    );
  }

  Widget _summary(
    List<Account> accounts,
    List<TransactionCategory> categories,
    String symbol,
  ) {
    String accountName(String? id) =>
        accounts.where((a) => a.id == id).firstOrNull?.name ??
        'Unavailable account';
    final format = NumberFormat.currency(symbol: symbol);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          format.format(_amount),
          style: const TextStyle(
            fontSize: KoinTypography.summaryAmount,
            fontWeight: KoinTypography.headingWeight,
          ),
        ),
        const SizedBox(height: 24),
        _line('Type', _income == null ? _typeLabel : 'Income claim'),
        if (_income != null)
          _line('Income', _income!.title)
        else if (_note.text.trim().isNotEmpty)
          _line('Note', _note.text.trim()),
        if (!_transfer)
          _line(
            'Category',
            categories.where((c) => c.id == _categoryId).firstOrNull?.name ??
                'Unavailable category',
          ),
        _line(_transfer ? 'From' : 'Account', accountName(_accountId)),
        if (_transfer) ...[
          _line('To', accountName(_destinationId)),
          _line('Fee', format.format(_transferDraft.calculateFeeAmount())),
          _line(
            'Amount received',
            format.format(_transferDraft.calculateNetAmount()),
          ),
        ],
        _line('Date', DateFormat.yMMMd().format(_date)),
        const SizedBox(height: 16),
        const Text('Check the details before saving.'),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: KoinTypography.labelWeight),
          ),
        ),
      ],
    ),
  );
}
