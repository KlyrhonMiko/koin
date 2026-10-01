
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/accounts.dart';
import 'package:koin/features/cashflow/cashflow.dart';
import 'package:koin/features/debts/debts.dart';
import 'package:koin/features/savings/savings.dart';

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
  static const _tabs = ['Accounts', 'Goals', 'Credit & IOUs', 'Planned', 'Incomes'];

  @override
  void initState() {
    _animationSessionKey = DateTime.now().millisecondsSinceEpoch.toString();
    super.initState();
    final initialTab = ref.read(portfolioTabProvider);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: (initialTab >= 0 && initialTab < _tabs.length) ? initialTab : 0,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticService.selection();
      } else {
        ref.read(portfolioTabProvider.notifier).setIndex(_tabController.index);
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


  @override
  Widget build(BuildContext context) {
    ref.listen<int>(portfolioTabProvider, (previous, next) {
      if (next >= 0 && next < _tabs.length && _tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

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
        } else {
          ref.read(portfolioTabProvider.notifier).setIndex(_tabController.index);
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
              SavingsTab(showEntranceAnimations: _showEntranceAnimations),
              DebtsTab(
                animationSessionKey: _animationSessionKey,
                showEntranceAnimations: _showEntranceAnimations,
              ),
              PlannedPaymentsTab(showEntranceAnimations: _showEntranceAnimations),
              RecurringIncomesTab(showEntranceAnimations: _showEntranceAnimations),
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
          onReorderItem: (oldIndex, newIndex) {
            HapticService.medium();
            ref
                .read(accountProvider.notifier)
                .reorderAccounts(oldIndex, newIndex);
          },
          proxyDecorator: koinReorderProxyDecorator,
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
                child: SwipeToDeleteTile(
                  key: Key('dismiss_${account.id}'),
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: AppTheme.errorColor(
                    context,
                  ).withValues(alpha: 0.15),
                  iconColor: AppTheme.errorColor(context),
                  icon: Icons.delete_rounded,
                  confirmTitle: 'Delete Account?',
                  confirmDescription:
                      'All transactions associated with this account will be unlinked. This cannot be undone.',
                  onDelete: () {
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
          .fade(duration: 250.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: 250.ms,
            curve: Curves.easeOutCubic,
          );
    }
    return button;
  }

  // ═══════════════════════════════════════════════════════
  // SAVINGS TAB
  // ═══════════════════════════════════════════════════════
  
  
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
                      ),
                  const SizedBox(height: 24),
                  Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                  const SizedBox(height: 36),
                  KoinPrimaryButton(
                    label: buttonLabel,
                    icon: Icons.add_rounded,
                    onPressed: onTap,
                  ),
                ]
                .animate(interval: 40.ms)
                .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  duration: 250.ms,
                  curve: Curves.easeOutCubic,
                ),
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
  
  
  // ═══════════════════════════════════════════════════════
  // GOAL CARD
  // ═══════════════════════════════════════════════════════
  }

// ═══════════════════════════════════════════════════════
// RADIAL PROGRESS PAINTER
// ═══════════════════════════════════════════════════════

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
