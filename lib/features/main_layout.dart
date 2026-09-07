import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:koin/core/utils/slide_up_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    void onItemTapped(int index) {
      if (currentIndex == index) return;
      HapticService.selection();
      ref.read(navigationProvider.notifier).setIndex(index);
    }

    final canGoBack = ref.read(navigationProvider.notifier).canPop();

    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        HapticService.light();
        ref.read(navigationProvider.notifier).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: _getPage(currentIndex),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(
                      context,
                    ).withValues(alpha: isDarkMode ? 0.7 : 0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.4 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: isDarkMode ? 0.08 : 0.05),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavItem(
                            context,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            isActive: currentIndex == 0,
                            targetIndex: 0,
                            onTap: onItemTapped,
                          ),
                          _buildNavItem(
                            context,
                            icon: Icons.receipt_long_outlined,
                            activeIcon: Icons.receipt_long_rounded,
                            isActive: currentIndex == 1,
                            targetIndex: 1,
                            onTap: onItemTapped,
                          ),
                          _buildNavItem(
                            context,
                            icon: Icons.savings_outlined,
                            activeIcon: Icons.savings_rounded,
                            isActive: currentIndex == 2,
                            targetIndex: 2,
                            onTap: onItemTapped,
                          ),
                          _buildNavItem(
                            context,
                            icon: Icons.account_balance_wallet_outlined,
                            activeIcon: Icons.account_balance_wallet_rounded,
                            isActive: currentIndex == 3,
                            targetIndex: 3,
                            onTap: onItemTapped,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  offset: Offset.zero,
                  child: _BreathingGlowFAB(
                    glowColor: AppTheme.primaryColor(context),
                    child: SizedBox(
                      width: 66,
                      height: 66,
                      child: FloatingActionButton(
                        onPressed: () {
                          HapticService.medium();
                          Navigator.push(
                            context,
                            SlideUpRoute(page: const AddTransactionScreen()),
                          );
                        },
                        elevation: 0,
                        backgroundColor: AppTheme.primaryColor(context),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        child: const Icon(Icons.add_rounded, size: 38),
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

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ActivityScreen();
      case 2:
        return const BudgetsScreen();
      case 3:
        return const PortfolioScreen();
      default:
        return const DashboardScreen();
    }
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required int targetIndex,
    required Function(int) onTap,
  }) {
    final primaryColor = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () => onTap(targetIndex),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        width: 56,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
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
                size: 24,
              ),
            );
          },
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

/// A wrapper that adds a breathing glow shadow to the FAB.
/// Uses a repeating animation to pulse the shadow blur radius
/// for a subtle, premium "alive" feeling.
class _BreathingGlowFAB extends StatefulWidget {
  final Widget child;
  final Color glowColor;

  const _BreathingGlowFAB({required this.child, required this.glowColor});

  @override
  State<_BreathingGlowFAB> createState() => _BreathingGlowFABState();
}

class _BreathingGlowFABState extends State<_BreathingGlowFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowValue = _glowAnimation.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.15 + 0.2 * glowValue,
                ),
                blurRadius: 10 + 16 * glowValue,
                spreadRadius: -2 + 4 * glowValue,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
