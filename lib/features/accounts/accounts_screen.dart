import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showEntranceAnimations = true;
  late final String _animationSessionKey;

  @override
  void initState() {
    _animationSessionKey = DateTime.now().millisecondsSinceEpoch.toString();
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
                      ),
                  const SizedBox(height: 24),
                              Text(
                                    'No accounts yet',
                                    style: TextStyle(
                                      color: AppTheme.textColor(context),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                              const SizedBox(height: 8),
                              Text(
                                    'Add your first account to see it here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.textLightColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                              const SizedBox(height: 36),
                              KoinPrimaryButton(
                                label: 'Add Your First Account',
                                icon: Icons.add_rounded,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    SlideUpRoute(
                                      page: const AccountFormScreen(),
                                    ),
                                  );
                                },
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

                  accountItem = accountItem
                      .animate(autoPlay: _showEntranceAnimations)
                      .fade(delay: (index * 60).ms, duration: 400.ms)
                      .slideY(
                        begin: 0.1,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      );

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
        bottom: 8,
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
                settings.hideBalance
                    ? Text(
                        '••••••',
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      )
                    : AnimatedCounter(
                        value: stats.currentBalance,
                        lastValueToken:
                            'portfolio_total_balance_$_animationSessionKey',
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

    return button
        .animate(autoPlay: _showEntranceAnimations)
        .fade(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
