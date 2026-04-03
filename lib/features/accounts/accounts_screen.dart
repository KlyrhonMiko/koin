import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/widgets/account_sheet.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/widgets/animated_counter.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showEntranceAnimations = true;

  @override
  void initState() {
    super.initState();
    // Only show entrance animations once
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showEntranceAnimations = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: const Alignment(0, -0.3),
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
                                      Icons.account_balance_wallet_rounded,
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
                                    'No accounts yet',
                                    style: TextStyle(
                                      color: AppTheme.textColor(context),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  )
                                  .animate()
                                  .slideY(
                                    begin: 0.2,
                                    delay: 300.ms,
                                    duration: 400.ms,
                                  )
                                  .fadeIn(),
                              const SizedBox(height: 8),
                              Text(
                                    'Add your first account to see it here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.textLightColor(context),
                                      fontSize: 14,
                                    ),
                                  )
                                  .animate()
                                  .slideY(
                                    begin: 0.2,
                                    delay: 400.ms,
                                    duration: 400.ms,
                                  )
                                  .fadeIn(),
                              const SizedBox(height: 36),
                              SizedBox(
                                    width: double.infinity,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: AppTheme.primaryGradient(
                                          context,
                                        ),
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
                                          AccountSheet.show(context, ref);
                                        },
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Add Your First Account',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .slideY(
                                    begin: 0.2,
                                    delay: 500.ms,
                                    duration: 400.ms,
                                  )
                                  .fadeIn(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                          1.0 +
                          (Curves.easeOut.transform(animation.value) * 0.03);
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

                  Widget accountItem = PressableScale(
                    onTap: () {
                      HapticService.light();
                      AccountSheet.show(context, ref, account: account);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Opacity(
                        opacity: account.excludeFromTotal ? 0.5 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: account.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: account.color.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    IconUtils.getIcon(account.iconCodePoint),
                                    color: account.color,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          account.name,
                                          style: TextStyle(
                                            color: AppTheme.textColor(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        if (account.excludeFromTotal) ...[
                                          const Gap(6),
                                          Icon(
                                            Icons.visibility_off_rounded,
                                            size: 14,
                                            color: AppTheme.textLightColor(
                                              context,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AnimatedCounter(
                                    value: balance,
                                    formatter: (v) => NumberFormat.currency(
                                      symbol: currency.symbol,
                                    ).format(v),
                                    duration: const Duration(milliseconds: 600),
                                    style: TextStyle(
                                      color: AppTheme.textColor(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(12),
                              Listener(
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
                            ],
                          ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PORTFOLIO',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Gap(4),
                AnimatedCounter(
                  value: stats.currentBalance,
                  formatter: (v) => fmt.format(v),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context, WidgetRef ref) {
    final button = PressableScale(
      onTap: () {
        HapticService.medium();
        AccountSheet.show(context, ref);
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
}
