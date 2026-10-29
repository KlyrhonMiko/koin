import 'dart:math' as math;

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
  static const _showEntranceAnimations = true;
  late final String _animationSessionKey;
  final GlobalKey _headerKey = GlobalKey();
  final Set<int> _cardSwipePointers = {};

  // Add more tabs here in the future (e.g., 'Investments')
  static const _tabs = [
    'Accounts',
    'Savings',
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
        _tabController.animateTo(
          next,
          duration: KoinMotion.duration(context, KoinMotion.entrance),
          curve: KoinMotion.curve,
        );
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
    final fmt = currency.formatter;

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
          PressableScale(
            semanticLabel: 'Choose portfolio section',
            enableHaptic: false,
            onTap: () => _showNavigationDropdown(context),
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
                        animation: _tabController.animation!,
                        builder: (context, child) {
                          return Text(
                            _tabs[_tabController.indexIsChanging
                                ? _tabController.index
                                : _tabController.animation!.value.round().clamp(
                                    0,
                                    _tabs.length - 1,
                                  )],
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
                      KoinIcons.caretDown,
                      size: 28,
                      color: AppTheme.primaryColor(context),
                    ),
                  ],
                ),
                const Gap(6),
                Text(
                  'Accounts · Savings · Credit & IOUs · Planned · Incomes',
                  style: TextStyle(
                    fontSize: KoinTypography.small,
                    color: AppTheme.textLightColor(context),
                  ),
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
  Future<void> _showNavigationDropdown(BuildContext context) async {
    HapticService.selection();
    final anchor = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null) return;
    final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final availableWidth = math.max(0.0, overlay.size.width - 32);
    final selection = await showMenu<int>(
      context: context,
      semanticLabel: 'Portfolio sections',
      position: RelativeRect.fromRect(
        Rect.fromLTWH(offset.dx, offset.dy + anchor.size.height + 6, 0, 0),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(
        minWidth: math.min(240, availableWidth),
        maxWidth: math.min(320, availableWidth),
      ),
      color: AppTheme.surfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.dividerColor(context)),
      ),
      items: [
        for (var index = 0; index < _tabs.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Semantics(
              selected: _tabController.index == index,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: _tabController.index == index
                            ? AppTheme.primaryColor(context)
                            : AppTheme.textColor(context),
                        fontSize: KoinTypography.body,
                        fontWeight: _tabController.index == index
                            ? KoinTypography.titleWeight
                            : KoinTypography.labelWeight,
                      ),
                    ),
                  ),
                  const Gap(12),
                  if (_tabController.index == index)
                    Icon(
                      KoinIcons.check,
                      size: 20,
                      color: AppTheme.primaryColor(context),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (!mounted || !context.mounted || selection == null) return;
    _tabController.animateTo(
      selection,
      duration: KoinMotion.duration(context, KoinMotion.entrance),
      curve: KoinMotion.curve,
    );
  }
}
