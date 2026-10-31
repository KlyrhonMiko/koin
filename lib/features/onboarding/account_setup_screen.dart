import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/app_startup.dart';
import 'package:koin/core/widgets/inputs/grouped_amount_formatter.dart';

/// One optional setup step; existing installations never enter this flow.
class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Cash');
  final _balance = TextEditingController(text: '0');
  final _balanceFocus = FocusNode();
  late Currency _currency;
  String? _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(settingsProvider).currency;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _balanceFocus.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> accounts) async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final account = accounts.firstWhere((a) => a.id == _accountId);
      final transactions = ref.read(transactionProvider).value;
      if (transactions == null) {
        throw StateError('Account activity is still loading');
      }
      final current = TransactionRules.balance(account, transactions);
      final balance = _currency.tryParseInput(_balance.text)!;
      await ref
          .read(accountProvider.notifier)
          .updateAccount(
            account.copyWith(
              name: _name.text.trim(),
              initialBalance: account.computeAdjustedInitialBalance(
                targetBalance: balance,
                currentBalance: current,
              ),
            ),
          );
      await ref.read(settingsProvider.notifier).setCurrency(_currency);
      await ref.read(settingsProvider.notifier).completeSetup();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not finish setup',
          subtitle: 'Your details are kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).completeSetup();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(context, 'Could not skip setup. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseCurrency(BuildContext context) async {
    final result = await showRadioSelectionSheet<Currency>(
      context: context,
      title: 'Currency',
      options: Currency.supportedCurrencies,
      selected: _currency,
      label: (c) => '${c.code} · ${c.name}',
      accentColor: AppTheme.primaryColor(context),
    );
    if (result != null && mounted) setState(() => _currency = result);
  }

  Future<void> _chooseAccount(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final result = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _accountId,
    );
    if (result != null && mounted) {
      setState(() {
        _accountId = result;
        _name.text = accounts.firstWhere((a) => a.id == result).name;
      });
    }
  }

  @override
  Widget build(BuildContext context) => KoinFormTheme(
    builder: (context) {
      final accounts = ref.watch(accountProvider);
      final transactions = ref.watch(transactionProvider);
      if ((accounts.isLoading && !accounts.hasValue) ||
          (transactions.isLoading && !transactions.hasValue)) {
        return const Scaffold(body: KoinStartupPlaceholder());
      }
      return PopScope(
        canPop: !_saving,
        child: Scaffold(
          body: SafeArea(
            child: accounts.when(
              loading: () => const KoinStartupPlaceholder(),
              error: (_, _) => KoinErrorState(
                onRetry: () => ref.invalidate(accountProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: TextButton(
                      onPressed: _saving ? null : _skip,
                      child: const Text('Continue to Koin'),
                    ),
                  );
                }
                final selected = items.firstWhere(
                  (a) => a.id == _accountId,
                  orElse: () => items.first,
                );
                if (_accountId != selected.id) {
                  _accountId = selected.id;
                  _name.text = selected.name;
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: _form,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Keep the action in reach on regular phones; allow
                          // the entire form to scroll with large text/keyboards.
                          final pinAction =
                              constraints.maxHeight >= 700 &&
                              MediaQuery.textScalerOf(context).scale(14) <=
                                  21 &&
                              MediaQuery.viewInsetsOf(context).bottom == 0;
                          final action = _actions(
                            context,
                            items,
                            enabled:
                                transactions.hasValue &&
                                !transactions.isLoading &&
                                !transactions.hasError,
                          );
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    KoinSpacing.screenInset,
                                    12,
                                    KoinSpacing.screenInset,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _intro(context),
                                      const SizedBox(height: 28),
                                      IgnorePointer(
                                        ignoring: _saving,
                                        child: KoinGroupedCard(
                                          borderRadius: KoinShape.field,
                                          dividerIndent: 66,
                                          children: [
                                            SelectionTile(
                                              asCard: false,
                                              selectedNameMaxLines: null,
                                              label: 'Currency',
                                              fallbackIcon: KoinIcons.money,
                                              selectedColor:
                                                  AppTheme.contentColor(
                                                    context,
                                                    AppTheme.primaryColor(
                                                      context,
                                                    ),
                                                  ),
                                              selectedIconCodePoint:
                                                  KoinIcons.money.codePoint,
                                              selectedName:
                                                  '${_currency.code} · ${_currency.name}',
                                              placeholder: 'Choose currency',
                                              onTap: () =>
                                                  _chooseCurrency(context),
                                            ),
                                            SelectionTile(
                                              asCard: false,
                                              selectedNameMaxLines: null,
                                              label: 'Account',
                                              fallbackIcon: KoinIcons.wallet,
                                              selectedColor:
                                                  AppTheme.contentColor(
                                                    context,
                                                    selected.color,
                                                  ),
                                              selectedIconCodePoint:
                                                  selected.iconCodePoint,
                                              selectedLogoAsset:
                                                  selected.logoAsset,
                                              selectedName: selected.name,
                                              placeholder: 'Choose account',
                                              onTap: () => _chooseAccount(
                                                context,
                                                items,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      _accountFields(context),
                                      const SizedBox(height: 24),
                                      _savingsNote(context),
                                      if (transactions.hasError)
                                        KoinErrorState(
                                          message: 'Could not load account activity.',
                                          onRetry: () => ref.invalidate(
                                            transactionProvider,
                                          ),
                                        ),
                                      if (!pinAction) ...[
                                        const SizedBox(height: 28),
                                        action,
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (pinAction)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    KoinSpacing.screenInset,
                                    12,
                                    KoinSpacing.screenInset,
                                    16,
                                  ),
                                  child: action,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _intro(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Koin',
                  style: KoinTypography.entityNameStyle.copyWith(
                    fontSize: KoinTypography.screenTitle,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _saving ? null : _skip,
              style: TextButton.styleFrom(
                overlayColor: AppTheme.primaryColor(context),
                minimumSize: const Size(48, 48),
                foregroundColor: AppTheme.textLightColor(context),
              ),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Semantics(
        header: true,
        child: Text(
          'Start with your balance',
          style: KoinTypography.entityNameStyle.copyWith(
            color: AppTheme.textColor(context),
            height: 1.15,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Choose your currency and add the money already in one account. You can add more accounts later.',
        style: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: KoinTypography.compact,
          height: 1.5,
        ),
      ),
    ],
  );

  InputDecoration _fieldDecoration(BuildContext context, String label) =>
      InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: const UnderlineInputBorder(),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.fieldBorderColor(context)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppTheme.contentColor(
              context,
              AppTheme.primaryColor(context),
            ),
            width: 2,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.errorColor(context)),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.errorColor(context), width: 2),
        ),
        helperMaxLines: 4,
        errorMaxLines: 4,
      );

  Widget _accountFields(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        key: const ValueKey('setup-name'),
        controller: _name,
        enabled: !_saving,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _balanceFocus.requestFocus(),
        style: TextStyle(
          fontSize: KoinTypography.cardAmount,
          fontWeight: KoinTypography.labelWeight,
          color: AppTheme.textColor(context),
        ),
        decoration: _fieldDecoration(context, 'Account name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter an account name'
            : null,
      ),
      const SizedBox(height: 24),
      TextFormField(
        key: const ValueKey('setup-balance'),
        controller: _balance,
        focusNode: _balanceFocus,
        enabled: !_saving,
        inputFormatters: const [GroupedAmountFormatter()],
        keyboardType: TextInputType.numberWithOptions(
          decimal: _currency.decimalDigits > 0,
        ),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _balanceFocus.unfocus(),
        style: KoinTypography.inputAmountStyle.copyWith(
          color: AppTheme.textColor(context),
        ),
        decoration: _fieldDecoration(context, 'Current balance').copyWith(
          hintText: _currency.decimalDigits == 0
              ? '0'
              : '0.${'0' * _currency.decimalDigits}',
          hintStyle: KoinTypography.inputAmountStyle.copyWith(
            color: AppTheme.textLightColor(context),
          ),
          prefixText: '${_currency.symbol} ',
          prefixStyle: TextStyle(
            fontSize: KoinTypography.screenTitle,
            fontWeight: KoinTypography.labelWeight,
            color: AppTheme.textLightColor(context),
          ),
          helperText: 'Enter what is in this account today.',
        ),
        validator: (value) {
          final amount = _currency.tryParseInput(value ?? '');
          return amount == null || amount < 0
              ? 'Enter a valid balance of zero or more'
              : null;
        },
      ),
    ],
  );

  Widget _savingsNote(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          KoinIcons.piggyBank,
          size: 20,
          color: AppTheme.textLightColor(context),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Savings reserve money in an account. Creating a savings goal does not add income.',
          style: TextStyle(
            fontSize: KoinTypography.caption,
            height: 1.45,
            color: AppTheme.textLightColor(context),
          ),
        ),
      ),
    ],
  );

  Widget _actions(
    BuildContext context,
    List<Account> accounts, {
    required bool enabled,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      KoinPrimaryButton(
        label: 'Start tracking',
        isLoading: _saving,
        enabled: enabled,
        onPressed: () => _save(accounts),
      ),
      const SizedBox(height: 14),
      Text(
        'Next, tap + on Home to record your first transaction.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: KoinTypography.small,
          height: 1.4,
          color: AppTheme.textLightColor(context),
        ),
      ),
    ],
  );
}
