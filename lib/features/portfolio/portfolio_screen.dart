import 'dart:math';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/features/accounts/screens/account_form_screen.dart';
import 'package:koin/core/widgets/account_item.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'package:koin/features/debts/debts_tab.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/features/planned_payments/add_edit_planned_payment_screen.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/widgets/payment_confirmation_sheet.dart';
import 'package:koin/core/utils/animation_utils.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showEntranceAnimations = true;
  late final String _animationSessionKey;
  final GlobalKey _headerKey = GlobalKey();

  // Add more tabs here in the future (e.g., 'Investments')
  static const _tabs = ['Accounts', 'Goals', 'Debts', 'Planned'];

  @override
  void initState() {
    _animationSessionKey = DateTime.now().millisecondsSinceEpoch.toString();
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticService.selection();
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showEntranceAnimations = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _paySubscription(
    BuildContext context,
    PlannedPayment payment,
  ) async {
    final result = await PaymentConfirmationSheet.show(
      context: context,
      payment: payment,
    );
    if (result == null || !context.mounted) return;

    final transaction = AppTransaction(
      id: const Uuid().v4(),
      note: '${payment.title} (Subscription)',
      amount: result.amount,
      type: payment.type,
      date: DateTime.now(),
      categoryId: result.categoryId,
      accountId: result.accountId,
      plannedPaymentId: payment.id,
    );

    DateTime nextDate = payment.nextDate;
    switch (payment.frequency) {
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
    }

    final updatedPayment = PlannedPayment(
      id: payment.id,
      title: payment.title,
      amount: payment.amount,
      type: payment.type,
      categoryId: payment.categoryId,
      accountId: payment.accountId,
      startDate: payment.startDate,
      endDate: payment.endDate,
      nextDate: nextDate,
      frequency: payment.frequency,
      notes: payment.notes,
      isAutoProcess: payment.isAutoProcess,
    );

    await ref.read(transactionProvider.notifier).addTransaction(transaction);
    await ref
        .read(plannedPaymentProvider.notifier)
        .updatePlannedPayment(updatedPayment);

    if (context.mounted) {
      KoinSnackBar.success(
        context,
        'Payment recorded successfully',
        subtitle: 'Your payment history has been updated',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recreate controller if length mismatch (e.g. during hot reload after adding tabs)
    if (_tabController.length != _tabs.length) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: oldIndex.clamp(0, _tabs.length - 1),
      );
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          HapticService.selection();
        }
      });
    }

    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══════════════════════════════════════════
        // FIXED HEADER: Dropdown Title + Balance
        // ═══════════════════════════════════════════
        _buildHeader(context, stats, fmt),

        // ═══════════════════════════════════════════
        // TAB CONTENT (each tab scrolls independently)
        // ═══════════════════════════════════════════
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAccountsTab(context, currency),
              _buildSavingsTab(context),
              DebtsTab(
                animationSessionKey: _animationSessionKey,
                showEntranceAnimations: _showEntranceAnimations,
              ),
              _buildPlannedTab(context),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER — Dropdown Navigation Title + total balance
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(
    BuildContext context,
    DashboardStats stats,
    NumberFormat fmt,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showNavigationDropdown(context),
            behavior: HitTestBehavior.opaque,
            child: Column(
              key: _headerKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PORTFOLIO',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        return Text(
                          _tabs[_tabController.index],
                          style: TextStyle(
                            color: AppTheme.textColor(context),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            height: 1.2,
                          ),
                        );
                      },
                    ),
                    const Gap(6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: AppTheme.primaryColor(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // NAVIGATION DROPDOWN
  // ═══════════════════════════════════════════════════════
  void _showNavigationDropdown(BuildContext context) {
    HapticService.selection();
    final renderBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final top = offset.dy + renderBox.size.height + 6;
    final left = offset.dx;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              child: FadeTransition(
                opacity: anim,
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (context, child) {
                    return Align(
                      alignment: const Alignment(0, -1),
                      heightFactor: Curves.easeOutCubic.transform(anim.value),
                      child: child,
                    );
                  },
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return _DropdownMenu(controller: _tabController, tabs: _tabs);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACCOUNTS TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildAccountsTab(BuildContext context, dynamic currency) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _buildFullEmptyState(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: 'No accounts yet',
            subtitle: 'Add your first account to start\ntracking your money',
            buttonLabel: 'Add Your First Account',
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                SlideUpRoute(page: const AccountFormScreen()),
              );
            },
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: accounts.length,
          footer: _buildAddAccountButton(context, ref),
          onReorder: (oldIndex, newIndex) {
            HapticService.medium();
            ref
                .read(accountProvider.notifier)
                .reorderAccounts(oldIndex, newIndex);
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final elevation =
                    Curves.easeOut.transform(animation.value) * 16;
                final scale =
                    1.0 + (Curves.easeOut.transform(animation.value) * 0.03);
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    shadowColor: AppTheme.primaryColor(
                      context,
                    ).withValues(alpha: 0.3),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final account = accounts[index];
            final balance = stats.accountBalances[account.id] ?? 0;

            Widget accountItem = AccountItem(
              account: account,
              balance: balance,
              currencySymbol: currency.symbol,
              animationSessionKey: _animationSessionKey,
              onTap: () {
                HapticService.light();
                Navigator.push(
                  context,
                  SlideUpRoute(page: AccountFormScreen(account: account)),
                );
              },
              onPrivateToggle: () {
                final updatedAccount = account.copyWith(
                  excludeFromTotal: !account.excludeFromTotal,
                );
                ref
                    .read(accountProvider.notifier)
                    .updateAccount(updatedAccount);
                HapticService.selection();
              },
              trailing: Listener(
                onPointerDown: (_) => HapticService.light(),
                child: ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.2),
                    size: 22,
                  ),
                ),
              ),
            );

            if (_showEntranceAnimations) {
              accountItem = accountItem
                  .animate()
                  .fade(delay: (index * 60).ms, duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  );
            }

            return KeyedSubtree(
              key: ValueKey(account.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: Key('dismiss_${account.id}'),
                  direction: DismissDirection.endToStart,
                  onUpdate: (details) {
                    if (details.reached && !details.previousReached) {
                      HapticService.selection();
                    }
                  },
                  background: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor(
                        context,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(
                      Icons.delete_rounded,
                      color: AppTheme.errorColor(context),
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    HapticService.medium();
                    final confirmed = await ConfirmationSheet.show(
                      context: context,
                      title: 'Delete Account?',
                      description:
                          'All transactions associated with this account will be unlinked. This cannot be undone.',
                      confirmLabel: 'Delete',
                      confirmColor: AppTheme.errorColor(context),
                      icon: Icons.delete_forever_rounded,
                      isDanger: true,
                    );
                    return confirmed ?? false;
                  },
                  onDismissed: (_) {
                    HapticService.heavy();
                    ref
                        .read(accountProvider.notifier)
                        .deleteAccount(account.id);
                  },
                  child: accountItem,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAddAccountButton(BuildContext context, WidgetRef ref) {
    final button = PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(context, SlideUpRoute(page: const AccountFormScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.textLightColor(context),
              size: 20,
            ),
            const Gap(10),
            Text(
              'Add New Account',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    if (_showEntranceAnimations) {
      return button
          .animate()
          .fade(delay: 300.ms, duration: 400.ms)
          .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic);
    }
    return button;
  }

  // ═══════════════════════════════════════════════════════
  // PLANNED TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildPlannedTab(BuildContext context) {
    final paymentsAsync = ref.watch(plannedPaymentProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final categories = ref.watch(categoriesProvider).value ?? [];

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return _buildFullEmptyState(
            context,
            icon: Icons.event_repeat_rounded,
            title: 'No subscriptions',
            subtitle:
                'Add recurring payments to track\nyour future obligations',
            buttonLabel: 'Add Your First Subscription',
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                SlideUpRoute(page: const AddEditPlannedPaymentScreen()),
              );
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () {
            HapticService.light();
            return ref
                .read(plannedPaymentProvider.notifier)
                .loadPlannedPayments();
          },
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: payments.length + 1,
            itemBuilder: (context, index) {
              if (index == payments.length) {
                return _buildAddPlannedButton(context);
              }
              final payment = payments[index];
              final category = categories
                  .cast<TransactionCategory?>()
                  .firstWhere(
                    (c) => c?.id == payment.categoryId,
                    orElse: () =>
                        categories.isNotEmpty ? categories.first : null,
                  );
              return Dismissible(
                key: Key('planned_${payment.id}'),
                direction: DismissDirection.endToStart,
                onUpdate: (details) {
                  if (details.reached && !details.previousReached) {
                    HapticService.selection();
                  }
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.expenseColor(context),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 28),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                confirmDismiss: (direction) async {
                  HapticService.medium();
                  return await ConfirmationSheet.show(
                    context: context,
                    title: 'Delete Subscription?',
                    description:
                        'Are you sure you want to delete "${payment.title}"? This action cannot be undone.',
                    confirmLabel: 'Delete',
                    confirmColor: AppTheme.expenseColor(context),
                    icon: Icons.delete_outline_rounded,
                    isDanger: true,
                  );
                },
                onDismissed: (_) {
                  HapticService.heavy();
                  ref
                      .read(plannedPaymentProvider.notifier)
                      .deletePlannedPayment(payment.id);
                },
                child: _buildPlannedPaymentCard(
                  context,
                  payment,
                  category,
                  currency,
                  index,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildPlannedPaymentCard(
    BuildContext context,
    PlannedPayment payment,
    dynamic category,
    dynamic currency,
    int index,
  ) {
    final isExpense = payment.type == TransactionType.expense;
    final amountColor = isExpense
        ? AppTheme.expenseColor(context)
        : AppTheme.incomeColor(context);

    final categoryColor = category != null
        ? Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')))
        : AppTheme.primaryColor(context);

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                category != null
                    ? IconUtils.getIcon(category.iconCodePoint)
                    : Icons.category_rounded,
                color: categoryColor,
                size: 24,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(6),
                  Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: AppTheme.textLightColor(context),
                      ),
                      const Gap(4),
                      Text(
                        payment.frequency.name.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (payment.isAutoProcess) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 10,
                                color: AppTheme.primaryColor(context),
                              ),
                              const Gap(2),
                              Text(
                                'AUTO',
                                style: TextStyle(
                                  color: AppTheme.primaryColor(context),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              "${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: currency.symbol).format(payment.amount)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const Gap(20),
        Container(
          height: 1,
          color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
        ),
        const Gap(16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppTheme.textLightColor(context),
                  ),
                ),
                const Gap(12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Payment',
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().format(payment.nextDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            InkWell(
              onTap: () {
                HapticService.light();
                _paySubscription(context, payment);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final cardItem = PressableScale(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          SlideUpRoute(page: AddEditPlannedPaymentScreen(payment: payment)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.textLightColor(context).withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: cardContent,
      ),
    );

    if (!AnimationTracker.hasSeen('port_pp_${payment.id}')) {
      return cardItem
          .animate()
          .fade(delay: (index * 50).ms)
          .slideY(begin: 0.1, curve: Curves.easeOutCubic);
    }

    return cardItem;
  }

  Widget _buildAddPlannedButton(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticService.medium();
        Navigator.push(
          context,
          SlideUpRoute(page: const AddEditPlannedPaymentScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, top: 4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: AppTheme.textLightColor(context),
              size: 20,
            ),
            const Gap(10),
            Text(
              'Add New Subscription',
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SAVINGS TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildSavingsTab(BuildContext context) {
    final goalsAsync = ref.watch(computedSavingsGoalsProvider);
    final settings = ref.watch(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return _buildFullEmptyState(
            context,
            icon: Icons.savings_rounded,
            title: 'No goals yet',
            subtitle: 'Start your savings journey by\ncreating your first goal',
            buttonLabel: 'Create Your First Goal',
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                SlideUpRoute(page: const AddSavingsGoalScreen()),
              );
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () {
            HapticService.light();
            return ref.read(savingsGoalsProvider.notifier).loadGoals();
          },
          color: AppTheme.primaryColor(context),
          backgroundColor: AppTheme.surfaceColor(context),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: goals.length + 2, // +1 hero, +1 add button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSavingsHeroCard(context, goals, currencyFormat);
              }
              if (index == goals.length + 1) {
                return _buildAddGoalButton(context, index);
              }
              final goal = goals[index - 1];
              return _buildGoalCard(context, goal, index, currencyFormat);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAddGoalButton(BuildContext context, int index) {
    return PressableScale(
          onTap: () {
            Navigator.push(
              context,
              SlideUpRoute(page: const AddSavingsGoalScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: AppTheme.textLightColor(context),
                  size: 20,
                ),
                const Gap(10),
                Text(
                  'Add New Goal',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  // ═══════════════════════════════════════════════════════
  // FULL EMPTY STATE (centered, for empty tabs)
  // ═══════════════════════════════════════════════════════
  Widget _buildFullEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.25),
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
                              color: AppTheme.primaryColor(
                                context,
                              ).withValues(alpha: 0.1),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          size: 56,
                          color: AppTheme.primaryColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      )
                      .animate()
                      .scale(
                        delay: 200.ms,
                        curve: Curves.easeOutBack,
                        duration: 600.ms,
                      )
                      .fadeIn(),
                  const SizedBox(height: 24),
                  Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 300.ms, duration: 400.ms)
                      .fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 400.ms, duration: 400.ms)
                      .fadeIn(),
                  const SizedBox(height: 36),
                  SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppTheme.primaryGradient(context),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticService.medium();
                              onTap();
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              buttonLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.2, delay: 500.ms, duration: 400.ms)
                      .fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SAVINGS HERO CARD (radial gauge summary)
  // ═══════════════════════════════════════════════════════
  Widget _buildSavingsHeroCard(
    BuildContext context,
    List<SavingsGoal> goals,
    NumberFormat currencyFormat,
  ) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final overallProgress = totalTarget > 0
        ? (totalSaved / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative circles
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Progress',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${goals.length} goal${goals.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(20),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: overallProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, child) {
                      final animatedPercent = (animatedProgress * 100)
                          .toStringAsFixed(0);
                      return SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _RadialProgressPainter(
                            progress: animatedProgress,
                            trackColor: Colors.white.withValues(alpha: 0.15),
                            progressColor: Colors.white,
                            strokeWidth: 8,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$animatedPercent%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 28,
                                    letterSpacing: -1,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'saved',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Gap(24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeroStat(
                          'Saved',
                          totalSaved,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStat(
                          'Target',
                          totalTarget,
                          currencyFormat,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildHeroStat(
                          'Remaining',
                          totalTarget - totalSaved,
                          currencyFormat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fade(duration: 500.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  Widget _buildHeroStat(String label, double amount, NumberFormat fmt) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(4),
        FittedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedCounter(
              value: amount,
              lastValueToken:
                  'portfolio_hero_${label.toLowerCase()}_$_animationSessionKey',
              formatter: (v) => fmt.format(v),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // GOAL CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildGoalCard(
    BuildContext context,
    SavingsGoal goal,
    int index,
    NumberFormat currencyFormat,
  ) {
    final progressPercent = (goal.progress * 100).toStringAsFixed(0);
    final isCompleted = goal.progress >= 1.0;

    final accentColors = [
      AppTheme.primaryColor(context),
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];
    final accentColor = accentColors[index % accentColors.length];

    return PressableScale(
          onTap: () {
            HapticService.light();
            Navigator.push(
              context,
              SlideUpRoute(page: SavingsDetailsScreen(goal: goal)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (isCompleted)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(4),
                                  Text(
                                    '${currencyFormat.format(goal.currentAmount)} of ${currencyFormat.format(goal.targetAmount)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textLightColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: goal.progress),
                            duration: Duration(
                              milliseconds: 800 + (index * 100),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedProgress, _) {
                              return LinearProgressIndicator(
                                value: animatedProgress,
                                backgroundColor: accentColor.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accentColor,
                                ),
                                minHeight: 5,
                              );
                            },
                          ),
                        ),
                        const Gap(12),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.5),
                            ),
                            const Gap(4),
                            Text(
                              '${goal.remainingDays}d left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: goal.remainingDays <= 7
                                    ? AppTheme.expenseColor(context)
                                    : AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.5),
                              ),
                            ),
                            const Gap(12),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(12),
                            Text(
                              '${currencyFormat.format(goal.dailyNeeded)}/day',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fade(delay: (index * 80).ms, duration: 400.ms)
        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}

// ═══════════════════════════════════════════════════════
// RADIAL PROGRESS PAINTER
// ═══════════════════════════════════════════════════════
class _RadialProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _DropdownMenu extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const _DropdownMenu({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppTheme.primaryColor(context).withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.4),
            width: 1,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (index) {
              final isSelected = controller.index == index;
              return InkWell(
                onTap: () {
                  HapticService.selection();
                  controller.animateTo(index);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor(context).withValues(alpha: 0.06)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Text(
                        tabs[index],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor(context)
                              : AppTheme.textColor(context),
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          color: AppTheme.primaryColor(context),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
