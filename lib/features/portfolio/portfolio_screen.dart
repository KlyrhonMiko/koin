import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
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
  final Set<int> _cardSwipePointers = {};

  // Add more tabs here in the future (e.g., 'Investments')
  static const _tabs = [
    'Accounts',
    'Goals',
    'Credit & IOUs',
    'Planned',
    'Incomes',
  ];

  @override
  void initState() {
    _animationSessionKey = DateTime.now().millisecondsSinceEpoch.toString();
    super.initState();
    final initialTab = ref.read(portfolioTabProvider);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: (initialTab >= 0 && initialTab < _tabs.length)
          ? initialTab
          : 0,
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
          ref
              .read(portfolioTabProvider.notifier)
              .setIndex(_tabController.index);
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
          child: NotificationListener<SwipeToDeletePointerNotification>(
            onNotification: (notification) {
              setState(() {
                if (notification.isDown) {
                  _cardSwipePointers.add(notification.pointer);
                } else {
                  _cardSwipePointers.remove(notification.pointer);
                }
              });
              return true;
            },
            child: TabBarView(
              controller: _tabController,
              physics: _cardSwipePointers.isNotEmpty
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: [
                AccountsTab(
                  animationSessionKey: _animationSessionKey,
                  showEntranceAnimations: _showEntranceAnimations,
                ),
                SavingsTab(showEntranceAnimations: _showEntranceAnimations),
                DebtsTab(
                  animationSessionKey: _animationSessionKey,
                  showEntranceAnimations: _showEntranceAnimations,
                ),
                PlannedPaymentsTab(
                  showEntranceAnimations: _showEntranceAnimations,
                ),
                RecurringIncomesTab(
                  showEntranceAnimations: _showEntranceAnimations,
                ),
              ],
            ),
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
        left: KoinSpacing.screenInset,
        right: KoinSpacing.screenInset,
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
                    fontSize: KoinTypography.small,
                    fontWeight: KoinTypography.titleWeight,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          return Text(
                            _tabs[_tabController.index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textColor(context),
                              fontSize: KoinTypography.summaryAmount,
                              fontWeight: KoinTypography.headingWeight,
                              letterSpacing: KoinTypography.amountTracking,
                              height: 1.2,
                            ),
                          );
                        },
                      ),
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
                    horizontal: KoinSpacing.screenInset,
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
                          fontSize: KoinTypography.body,
                          fontWeight: isSelected
                              ? KoinTypography.titleWeight
                              : KoinTypography.labelWeight,
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
