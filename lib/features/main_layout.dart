import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:koin/features/dashboard/dashboard.dart';
import 'package:koin/features/activity/activity_screen.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/features/transactions/transactions.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final List<Widget?> _pages = List.filled(4, null);
  static const _labels = ['Home', 'Activity', 'Budgets', 'Portfolio'];
  static const _icons = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.savings_outlined,
    Icons.account_balance_wallet_outlined,
  ];
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.savings_rounded,
    Icons.account_balance_wallet_rounded,
  ];

  void _select(int index) {
    if (ref.read(navigationProvider) == index) return;
    HapticService.selection();
    ref.read(navigationProvider.notifier).setIndex(index);
  }

  Widget _addTransaction(BuildContext context, {double size = 66}) => SizedBox(
    width: size,
    height: size,
    child: _GlowFAB(
      glowColor: AppTheme.primaryColor(context),
      child: FloatingActionButton(
        tooltip: 'Add transaction',
        onPressed: () {
          HapticService.medium();
          Navigator.push(
            context,
            SlideUpRoute(page: const AddTransactionScreen()),
          );
        },
        elevation: 0,
        backgroundColor: AppTheme.primaryColor(context),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 38),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    _pages[currentIndex] ??= _getPage(currentIndex);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canGoBack = ref.read(navigationProvider.notifier).canPop();
    final expanded = MediaQuery.sizeOf(context).width >= 840;
    final pages = IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < 4; i++)
          ExcludeFocus(
            excluding: i != currentIndex,
            child: TickerMode(
              enabled: i == currentIndex,
              child: _pages[i] ?? const SizedBox.shrink(),
            ),
          ),
      ],
    );
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        HapticService.light();
        ref.read(navigationProvider.notifier).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: AppTheme.surfaceColor(context),
          systemNavigationBarContrastEnforced: false,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          extendBody: !expanded,
          body: expanded
              ? Row(
                  children: [
                    SafeArea(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: _select,
                        extended:
                            MediaQuery.textScalerOf(context).scale(12) > 18,
                        labelType:
                            MediaQuery.textScalerOf(context).scale(12) > 18
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        minWidth: 96,
                        minExtendedWidth: 240,
                        backgroundColor: AppTheme.surfaceColor(context),
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _addTransaction(context, size: 56),
                        ),
                        destinations: [
                          for (var i = 0; i < 4; i++)
                            NavigationRailDestination(
                              icon: Icon(_icons[i]),
                              selectedIcon: Icon(_activeIcons[i]),
                              label: Text(_labels[i]),
                            ),
                        ],
                      ),
                    ),
                    Expanded(child: pages),
                  ],
                )
              : pages,
          bottomNavigationBar: expanded
              ? null
              : _bottomNavigation(context, currentIndex, dark),
        ),
      ),
    );
  }

  Widget _bottomNavigation(BuildContext context, int index, bool dark) {
    final narrow = MediaQuery.sizeOf(context).width < 320;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 0, narrow ? 12 : 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context)
                      .withValues(alpha: dark ? 0.7 : 0.85),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    AppTheme.boxShadow(
                      context,
                      color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: (dark ? Colors.white : Colors.black).withValues(
                      alpha: dark ? 0.08 : 0.05,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: _buildNavItem(context, i, index == i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: narrow ? 8 : 12),
            _addTransaction(context, size: narrow ? 54 : 66),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, bool active) {
    final primary = AppTheme.primaryColor(context);
    return Tooltip(
      excludeFromSemantics: true,
      message: _labels[index],
      child: PressableScale(
        semanticLabel: _labels[index],
        selected: active,
        enableHaptic: false,
        onTap: () => _select(index),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: active ? 1 : 0),
              duration: KoinMotion.duration(context, KoinMotion.feedback),
              curve: KoinMotion.curve,
              builder: (context, value, child) => Transform.scale(
                scale: 0.9 + value * 0.1,
                child: Icon(
                  active ? _activeIcons[index] : _icons[index],
                  color: Color.lerp(
                    AppTheme.textLightColor(context).withValues(alpha: 0.5),
                    primary,
                    value,
                  ),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getPage(int index) => switch (index) {
    0 => const DashboardScreen(),
    1 => const ActivityScreen(),
    2 => const BudgetsScreen(),
    3 => const PortfolioScreen(),
    _ => const DashboardScreen(),
  };
}

class AnimatedClipRect extends StatelessWidget {
  final Widget child;
  final bool open;
  final bool horizontalAnimation;
  final bool verticalAnimation;
  final Alignment alignment;
  final Duration duration;
  final Curve curve;

  const AnimatedClipRect({
    super.key,
    required this.child,
    required this.open,
    this.horizontalAnimation = true,
    this.verticalAnimation = true,
    this.alignment = Alignment.center,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.linear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: KoinMotion.duration(context, duration),
      curve: curve,
      alignment: alignment,
      child: ClipRect(
        child: Align(
          alignment: alignment,
          heightFactor: verticalAnimation ? (open ? 1.0 : 0.0) : 1.0,
          widthFactor: horizontalAnimation ? (open ? 1.0 : 0.0) : 1.0,
          child: open ? child : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Keep the FAB glow without continuously rendering frames while idle.
class _GlowFAB extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const _GlowFAB({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: glowColor.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
