import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';

class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  /// Displays [VoiceInputSheet] in a modal bottom sheet and returns parsed transaction data if accepted.
  static Future<ParsedTransactionData?> show(BuildContext context) async {
    HapticService.selection();
    final voice = ProviderScope.containerOf(context)
        .read(voiceInputProvider.notifier);
    try {
      return await showModalBottomSheet<ParsedTransactionData>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const VoiceInputSheet(),
      );
    } finally {
      await voice.stopListening();
    }
  }

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _ringController;

  ParsedTransactionData? _parsedData;
  String? _amountError;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  int _parseRevision = 0;
  bool _categorySuggested = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceInputProvider.notifier).startListening();
    });
  }

  void _syncListeningMotion(bool listening) {
    if (listening && !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      if (!_ringController.isAnimating) _ringController.repeat();
    } else {
      _pulseController.stop();
      _ringController.stop();
      _pulseController.value = 0;
      _ringController.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncListeningMotion(ref.read(voiceInputProvider).isListening);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _parseCurrentWords() async {
    final revision = ++_parseRevision;
    final state = ref.read(voiceInputProvider);
    final categories = ref.read(categoriesProvider).value ?? [];
    final transactions = ref.read(transactionProvider).value ?? [];
    final accounts = ref.read(accountProvider).value ?? [];

    if (state.lastWords.isNotEmpty) {
      final words = state.lastWords;
      _categorySuggested = false;
      var parsed = VoiceCommandParser.parse(
        state.lastWords,
        categories,
        transactions,
        accounts,
      );
      _amountController.text =
          parsed.amount?.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '') ??
          '';
      _noteController.text = parsed.note;

      // Enhance with CategorySuggester Seam
      final suggester = ref.read(categorySuggesterProvider);
      final amount = parsed.amount ?? 0.0;
      final effectiveAmount = amount == 0.0 ? 1.0 : amount;

      try {
        final suggestion = await suggester.suggest(
          SuggestionContext(
            text: parsed.note,
            amount: effectiveAmount,
            type: parsed.type,
            date: DateTime.now(),
            currentAccountId: parsed.account?.id ?? '',
          ),
        );

        if (!mounted ||
            revision != _parseRevision ||
            words != ref.read(voiceInputProvider).lastWords) {
          return;
        }
        if (suggestion != null &&
            suggestion.canAutoApply &&
            suggestion.type == parsed.type &&
            parsed.category == null) {
          TransactionCategory? cat = parsed.category;
          Account? acc = parsed.account;
          Account? toAcc = parsed.toAccount;

          if (suggestion.isTransfer) {
            try {
              acc ??= accounts.firstWhere(
                (a) => a.id == suggestion.originAccountId,
              );
            } catch (_) {}
            try {
              toAcc ??= accounts.firstWhere(
                (a) => a.id == suggestion.destinationAccountId,
              );
            } catch (_) {}
            cat = null;
          } else {
            try {
              acc ??= accounts.firstWhere(
                (a) => a.id == suggestion.originAccountId,
              );
            } catch (_) {}
            try {
              final newCat = categories.firstWhere(
                (c) => c.id == suggestion.categoryId,
              );
              if (newCat != cat) {
                cat = newCat;
                _categorySuggested = true;
              }
            } catch (_) {}
            toAcc = null;
          }

          parsed = parsed.copyWith(
            type: suggestion.type,
            category: cat,
            account: acc,
            toAccount: toAcc,
          );
        }
      } catch (e) {
        // Suggester enhancement failed, silently fallback to static parsing
      }

      if (mounted && revision == _parseRevision) {
        setState(() {
          _parsedData = parsed;
        });
      }
    }
  }

  void _onConfirm() {
    if (_parsedData == null || !mounted) return;
    final amount = ref
        .read(settingsProvider)
        .currency
        .tryParseInput(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _amountError = amount == null
            ? 'Enter a valid amount'
            : 'Amount must be greater than zero';
      });
      return;
    }
    HapticService.medium();
    Navigator.pop(context, _parsedData!.copyWith(amount: amount));
  }

  void _onStopListening() async {
    HapticService.medium();
    await ref.read(voiceInputProvider.notifier).stopListening();
    _parseCurrentWords();
  }

  void _onCancel() {
    HapticService.light();
    ref.read(voiceInputProvider.notifier).stopListening();
    Navigator.pop(context, null);
  }

  // ═══════════════════════════════════════════════════════
  // Selection Helpers
  // ═══════════════════════════════════════════════════════
  Future<void> _editCategory() async {
    _parseRevision++;
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final categories = ref.read(categoriesProvider).value ?? [];

    final id = await showCategoryPickerSheet(
      context: context,
      ref: ref,
      selectedCategoryId: _parsedData!.category?.id,
      type: _parsedData!.type,
      categoriesOverride: categories,
      indicatorColor: _getTypeColor(context, _parsedData!.type),
    );
    if (id != null && mounted) {
      final category = categories.firstWhere((c) => c.id == id);
      setState(() {
        _categorySuggested = false;
        _parsedData = _parsedData!.copyWith(
          category: category,
          isCategoryExplicit: true,
        );
      });
    }
  }

  Future<void> _editAccount() async {
    _parseRevision++;
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final accounts = ref.read(accountProvider).value ?? [];

    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _parsedData!.account?.id,
      title: 'Account',
      subtitle: 'Choose an account for this transaction',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      final account = accounts.firstWhere((a) => a.id == id);
      setState(() {
        _parsedData = _parsedData!.copyWith(account: account);
      });
    }
  }

  Future<void> _editToAccount() async {
    _parseRevision++;
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final accounts = ref.read(accountProvider).value ?? [];

    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _parsedData!.toAccount?.id,
      title: 'Destination Account',
      subtitle: 'Choose where the money arrives',
      accountsOverride: accounts,
      excludeAccountId: _parsedData!.account?.id,
    );
    if (id != null && mounted) {
      final account = accounts.firstWhere((a) => a.id == id);
      setState(() {
        _parsedData = _parsedData!.copyWith(toAccount: account);
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // Styling Helpers
  // ═══════════════════════════════════════════════════════

  Color _getTypeColor(BuildContext context, TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return AppTheme.expenseColor(context);
      case TransactionType.income:
        return AppTheme.incomeColor(context);
      case TransactionType.transfer:
        return AppTheme.transferColor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      voiceInputProvider.select((state) => state.isListening),
      (_, isListening) => _syncListeningMotion(isListening),
    );
    final state = ref.watch(voiceInputProvider);
    final primaryColor = AppTheme.primaryColor(context);
    final hasWords = state.lastWords.isNotEmpty;
    final showPreview = _parsedData != null && !state.isListening;

    // Parse on-the-fly when listening stops and we haven't parsed yet
    if (!state.isListening && hasWords && _parsedData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseCurrentWords();
      });
    }

    if (showPreview) {
      return KoinFormTheme(builder: _buildReviewSheet);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        16,
        KoinSpacing.screenInset,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KoinShape.sheet),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(KoinSpacing.sectionGap),

            // ── Animated mic orb ──
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final isListening = state.isListening;
                return PressableScale(
                  onTap: isListening ? _onStopListening : _onCancel,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring
                        if (isListening)
                          AnimatedBuilder(
                            animation: _ringController,
                            builder: (context, child) {
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor.withValues(
                                      alpha: 0.12 * (1 - _ringController.value),
                                    ),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        // Middle glow ring
                        if (isListening)
                          Container(
                            width: 96 + 8 * _pulseAnimation.value,
                            height: 96 + 8 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(
                                alpha: 0.06 + 0.04 * _pulseAnimation.value,
                              ),
                            ),
                          ),
                        // Core button
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isListening
                                  ? [
                                      primaryColor,
                                      primaryColor.withValues(alpha: 0.85),
                                    ]
                                  : [
                                      AppTheme.surfaceColor(context),
                                      AppTheme.surfaceLightColor(context),
                                    ],
                            ),
                            boxShadow: isListening
                                ? [
                                    AppTheme.boxShadow(
                                      context,
                                      color: primaryColor.withValues(
                                        alpha:
                                            0.2 + 0.15 * _pulseAnimation.value,
                                      ),
                                      blurRadius:
                                          20 + 10 * _pulseAnimation.value,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [
                                    AppTheme.boxShadow(
                                      context,
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                            border: isListening
                                ? null
                                : Border.all(
                                    color: AppTheme.dividerColor(context)
                                        .withValues(alpha: 0.5),
                                  ),
                          ),
                          child: Icon(
                            isListening ? KoinIcons.stop : KoinIcons.x,
                            size: 32,
                            color: isListening
                                ? Colors.white
                                : AppTheme.textLightColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Gap(20),

            // ── Status label ──
            AnimatedSwitcher(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 200),
              ),
              child: Text(
                state.isListening
                    ? 'Listening…'
                    : state.error.isNotEmpty
                    ? 'Something went wrong'
                    : 'Processing…',
                key: ValueKey(
                  state.isListening
                      ? 'listening'
                      : state.error.isNotEmpty
                      ? 'error'
                      : 'processing',
                ),
                style: TextStyle(
                  fontSize: KoinTypography.sectionTitle,
                  fontWeight: KoinTypography.headingWeight,
                  color: state.error.isNotEmpty
                      ? AppTheme.errorColor(context)
                      : AppTheme.textColor(context),
                  letterSpacing: KoinTypography.headingTracking,
                ),
              ),
            ),
            const Gap(6),

            // ── Hint / error subtitle ──
            AnimatedSwitcher(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 200),
              ),
              child: Text(
                state.error.isNotEmpty
                    ? state.error
                    : state.isListening
                    ? 'Tap the button when done'
                    : 'Almost there…',
                key: ValueKey('sub_${state.error}_${state.isListening}'),
                style: TextStyle(
                  fontSize: KoinTypography.caption,
                  fontWeight: KoinTypography.supportingWeight,
                  color: state.error.isNotEmpty
                      ? AppTheme.errorColor(context).withValues(alpha: 0.7)
                      : AppTheme.textLightColor(context),
                ),
              ),
            ),
            const Gap(24),

            // ── Transcription card (visible while listening or if no preview) ──
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasWords
                      ? primaryColor.withValues(alpha: 0.25)
                      : AppTheme.dividerColor(context).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                hasWords ? state.lastWords : 'Try: "Spent 50 on lunch"',
                key: ValueKey(hasWords ? state.lastWords : 'placeholder'),
                style: TextStyle(
                  fontSize: KoinTypography.body,
                  fontWeight: hasWords
                      ? KoinTypography.labelWeight
                      : FontWeight.w400,
                  fontStyle: hasWords ? FontStyle.normal : FontStyle.italic,
                  color: hasWords
                      ? AppTheme.textColor(context)
                      : AppTheme.textLightColor(context).withValues(alpha: 0.5),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Gap(8),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSheet(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        (media.size.height - media.padding.top - media.viewInsets.bottom - 16)
            .clamp(0.0, double.infinity);
    final scrollEverything =
        availableHeight < 420 ||
        media.textScaler.scale(KoinTypography.body) > 24;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KoinBottomSheetHandle(
          padding: EdgeInsets.only(top: 12, bottom: 8),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Review transaction',
                style: TextStyle(
                  fontSize: KoinTypography.sectionTitle,
                  fontWeight: KoinTypography.headingWeight,
                  color: AppTheme.textColor(context),
                  letterSpacing: KoinTypography.headingTracking,
                ),
              ),
            ),
            IconButton(
              onPressed: _onCancel,
              tooltip: 'Close voice review',
              icon: const Icon(KoinIcons.x, size: 20),
            ),
          ],
        ),
        const Gap(12),
      ],
    );
    final actions = Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticService.light();
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _parsedData = null;
                  _amountError = null;
                });
                ref.read(voiceInputProvider.notifier).startListening();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
                foregroundColor: AppTheme.textColor(context),
                side: BorderSide(color: AppTheme.fieldBorderColor(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KoinShape.field),
                ),
                textStyle: KoinTypography.choiceLabelStyle,
              ),
              icon: const Icon(KoinIcons.arrowClockwise, size: 16),
              label: const Text('Retry'),
            ),
          ),
          const Gap(12),
          Expanded(
            flex: 2,
            child: KoinPrimaryButton(
              label: 'Use details',
              icon: KoinIcons.check,
              onPressed: _onConfirm,
            ),
          ),
        ],
      ),
    );
    final body = _buildReviewBody(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: KoinSheetSurface(
        color: AppTheme.backgroundColor(context),
        constraints: BoxConstraints(maxHeight: availableHeight),
        padding: EdgeInsets.fromLTRB(
          KoinSpacing.screenInset,
          0,
          KoinSpacing.screenInset,
          media.padding.bottom + 16,
        ),
        child: scrollEverything
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [header, body, actions],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  Flexible(child: SingleChildScrollView(child: body)),
                  actions,
                ],
              ),
      ),
    );
  }

  Widget _buildReviewBody(BuildContext context) {
    final data = _parsedData!;
    final currency = ref.watch(settingsProvider).currency;
    final typeColor = _getTypeColor(context, data.type);
    final textColor = AppTheme.textColor(context);
    final mutedColor = AppTheme.textLightColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Amount · ${currency.code}',
              style: TextStyle(
                fontSize: KoinTypography.caption,
                fontWeight: KoinTypography.labelWeight,
                color: mutedColor,
              ),
            ),
            if (_amountError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _amountError!,
                  style: TextStyle(
                    fontSize: KoinTypography.small,
                    fontWeight: KoinTypography.labelWeight,
                    color: AppTheme.errorContentColor(context),
                  ),
                ),
              ),
          ],
        ),
        Semantics(
          label: 'Amount in ${currency.code}',
          hint: _amountError,
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            style: KoinTypography.inputAmountStyle.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '${currency.symbol} ',
              prefixStyle: TextStyle(
                fontSize: KoinTypography.screenTitle,
                fontWeight: KoinTypography.labelWeight,
                color: mutedColor,
              ),
              hintStyle: KoinTypography.inputAmountStyle.copyWith(
                color: mutedColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.only(top: 4, bottom: 16),
            ),
            onChanged: (value) {
              final amount = currency.tryParseInput(value);
              setState(() {
                _amountError = null;
                if (amount != null) {
                  _parsedData = _parsedData!.copyWith(amount: amount);
                }
              });
            },
          ),
        ),
        TransactionTypeSelector(
          selectedType: data.type,
          activeColor: typeColor,
          onChanged: (value) {
            if (value == data.type) return;
            _parseRevision++;
            _categorySuggested = false;
            setState(() {
              _parsedData = _parsedData!.copyWith(
                type: value,
                category: null,
                isCategoryExplicit: false,
                toAccount: null,
              );
            });
          },
        ),
        const Gap(20),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(KoinShape.field),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.type != TransactionType.transfer) ...[
                SelectionTile(
                  asCard: false,
                  minHeight: 72,
                  onTap: _editCategory,
                  fallbackIcon: KoinIcons.squaresFour,
                  selectedName: data.category?.name,
                  selectedColor: data.category?.color,
                  selectedIconCodePoint: data.category?.iconCodePoint,
                  selectedNameMaxLines: null,
                  placeholder: 'Select category',
                  label: 'Category',
                ),
                _buildPreviewDivider(context),
              ],
              _buildAccountSelection(
                context,
                account: data.account,
                onTap: _editAccount,
                label: data.type == TransactionType.transfer
                    ? 'From account'
                    : 'Account',
              ),
              if (data.type == TransactionType.transfer) ...[
                _buildPreviewDivider(context),
                _buildAccountSelection(
                  context,
                  account: data.toAccount,
                  onTap: _editToAccount,
                  label: 'To',
                  destination: true,
                ),
              ],
            ],
          ),
        ),
        const Gap(16),
        TextField(
          controller: _noteController,
          minLines: 1,
          maxLines: 3,
          style: TextStyle(fontSize: KoinTypography.body, color: textColor),
          decoration: InputDecoration(
            labelText: 'Note',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'Add a note',
            hintStyle: TextStyle(color: mutedColor),
            labelStyle: TextStyle(color: mutedColor),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.dividerColor(context)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.dividerColor(context)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor(context)),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _parseRevision++;
              _parsedData = _parsedData!.copyWith(
                note: value,
                category: _categorySuggested ? null : _parsedData!.category,
              );
              _categorySuggested = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAccountSelection(
    BuildContext context, {
    required Account? account,
    required String label,
    required VoidCallback onTap,
    bool destination = false,
  }) {
    final currency = ref.watch(settingsProvider).currency;
    final balances = ref.watch(dashboardStatsProvider).accountBalances;
    final goals = ref.watch(savingsGoalsProvider).value ?? [];
    final balance = account == null
        ? 0.0
        : balances[account.id] ?? account.initialBalance;
    final reserved =
        destination ||
            account == null ||
            account.isCredit ||
            _parsedData!.type == TransactionType.income
        ? 0.0
        : goals
              .where((g) => g.linkedAccountId == account.id)
              .fold<double>(0, (sum, g) => sum + g.currentAmount);
    final displayBalance = destination
        ? balance
        : (balance - reserved).clamp(0, double.infinity);
    return SelectionTile(
      asCard: false,
      minHeight: 72,
      fallbackIcon: KoinIcons.wallet,
      label: reserved > 0 ? 'Spendable' : label,
      selectedName: account == null
          ? null
          : '${account.name} • ${currency.formatter.format(displayBalance)}',
      selectedColor: account?.color,
      selectedIconCodePoint: account?.iconCodePoint,
      selectedLogoAsset: account?.logoAsset,
      selectedNameMaxLines: null,
      placeholder: destination ? 'Select destination' : 'Select account',
      onTap: onTap,
    );
  }

  Widget _buildPreviewDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.dividerColor(context).withValues(alpha: 0.4),
    );
  }
}
