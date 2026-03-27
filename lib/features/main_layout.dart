import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/accounts/accounts_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:koin/features/activity/activity_screen.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/core/providers/navigation_provider.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';

import 'package:koin/core/utils/haptic_utils.dart';

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    final isDarkMode = ref.watch(settingsProvider).isDarkMode;

    void onItemTapped(int index) {
      if (currentIndex == index) return;
      HapticService.selection();
      ref.read(navigationProvider.notifier).setIndex(index);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: AppTheme.surfaceColor(context),
        systemNavigationBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: _getPage(currentIndex),
          ),
        ),
        floatingActionButton: currentIndex != 4
            ? FloatingActionButton.extended(
                onPressed: () {
                  HapticService.medium();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                  );
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: ClipRect(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: currentIndex == 2 ? 0.0 : 1.0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: currentIndex == 2 ? 0.0 : 1.0,
                            child: const Text(' Transaction', 
                              style: TextStyle(fontWeight: FontWeight.bold), 
                              maxLines: 1, 
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                icon: const Icon(Icons.add_rounded),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context).withValues(alpha: isDarkMode ? 0.7 : 0.85),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: isDarkMode ? 0.08 : 0.05),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                    _buildNavItem(
                      context,
                      icon: Icons.credit_card_outlined,
                      activeIcon: Icons.credit_card_rounded,
                      label: 'Accounts',
                      isActive: currentIndex == 0,
                      targetIndex: 0,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Activity',
                      isActive: currentIndex == 1,
                      targetIndex: 1,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Home',
                      isActive: currentIndex == 2,
                      targetIndex: 2,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      activeIcon: Icons.account_balance_wallet_rounded,
                      label: 'Budgets',
                      isActive: currentIndex == 3,
                      targetIndex: 3,
                      onTap: onItemTapped,
                    ),
                    _buildNavItem(
                      context,
                      icon: Icons.savings_outlined,
                      activeIcon: Icons.savings_rounded,
                      label: 'Savings',
                      isActive: currentIndex == 4,
                      targetIndex: 4,
                      onTap: onItemTapped,
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return const AccountsScreen();
      case 1: return const ActivityScreen();
      case 2: return const DashboardScreen();
      case 3: return const BudgetsScreen();
      case 4: return const SavingsListScreen();
      default: return const DashboardScreen();
    }
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required int targetIndex,
    required Function(int) onTap,
  }) {
    final primaryColor = AppTheme.primaryColor(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onTap(targetIndex),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: isDarkMode ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.15),
              blurRadius: 12,
              spreadRadius: -2,
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isActive ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.9 + (value * 0.1),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: Color.lerp(
                      AppTheme.textLightColor(context).withValues(alpha: 0.5),
                      primaryColor,
                      value,
                    ),
                    size: 22,
                  ),
                );
              },
            ),
            AnimatedClipRect(
              open: isActive,
              horizontalAnimation: true,
              verticalAnimation: false,
              alignment: Alignment.centerLeft,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      duration: duration,
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
