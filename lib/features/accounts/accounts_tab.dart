import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/cards/account_card_layout.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/accounts/account_reorder_grid.dart';

/// Modular Accounts Tab: Encapsulates account listing, balance rendering,
/// swipe-to-delete, drag-and-drop reordering, and empty state.
class AccountsTab extends ConsumerWidget {
  final String animationSessionKey;
  final bool showEntranceAnimations;

  const AccountsTab({
    super.key,
    required this.animationSessionKey,
    required this.showEntranceAnimations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final goals = ref.watch(savingsGoalsProvider).value ?? [];

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _buildEmptyState(context);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(13) > 19.5;
            final width = constraints.maxWidth - KoinSpacing.screenInset * 2;
            final columns = width < 280 || largeText ? 1 : 2;
            final cardWidth =
                (width - KoinSpacing.cardGap * (columns - 1)) / columns;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                KoinSpacing.screenInset,
                12,
                KoinSpacing.screenInset,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (accounts.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: 16,
                            color: AppTheme.textLightColor(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hold and drag to rearrange',
                              style: TextStyle(
                                fontSize: KoinTypography.small,
                                color: AppTheme.textLightColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  AccountReorderGrid(
                    columns: columns,
                    cardWidth: cardWidth,
                    cardHeight:
                        AccountCardLayout.minimumHeight(context) +
                        (accounts.any(
                              (a) =>
                                  !a.excludeFromTotal &&
                                  goals.any(
                                    (g) =>
                                        g.linkedAccountId == a.id &&
                                        g.includeInDashboardBalance &&
                                        g.currentAmount > 0,
                                  ),
                            )
                            ? 2 +
                                  MediaQuery.textScalerOf(context)
                                          .scale(KoinTypography.small) *
                                      1.5
                            : 0),
                    onReorder: (id, to) {
                      final current = ref.read(accountProvider).value ?? [];
                      final from = current.indexWhere((a) => a.id == id);
                      if (from >= 0 && from != to) {
                        HapticService.selection();
                        ref
                            .read(accountProvider.notifier)
                            .reorderAccounts(from, to);
                      }
                    },
                    addButton: _buildAddAccountButton(context),
                    items: [
                      ...List.generate(accounts.length, (index) {
                        final account = accounts[index];
                        final balance = stats.accountBalances[account.id] ?? 0;
                        final excludedSavings = goals
                            .where(
                              (g) =>
                                  g.linkedAccountId == account.id &&
                                  !g.includeInDashboardBalance &&
                                  g.currentAmount > 0,
                            )
                            .fold<double>(0, (sum, g) => sum + g.currentAmount);
                        final displayBalance =
                            balance -
                            excludedSavings.clamp(
                              0,
                              balance.clamp(0, double.infinity),
                            );

                        Widget accountItem = AccountItem(
                          compact: true,
                          account: account,
                          balance: displayBalance,
                          savingsAmount: goals
                              .where(
                                (g) =>
                                    g.linkedAccountId == account.id &&
                                    g.includeInDashboardBalance &&
                                    g.currentAmount > 0,
                              )
                              .fold<double>(
                                0,
                                (sum, g) => sum + g.currentAmount,
                              ),
                          currencySymbol: currency.symbol,
                          currency: currency,
                          animationSessionKey: animationSessionKey,
                          onTap: () {
                            HapticService.light();
                            Navigator.push(
                              context,
                              SlideUpRoute(
                                page: AccountFormScreen(account: account),
                              ),
                            );
                          },
                          onPrivateToggle: () async {
                            final updatedAccount = account.copyWith(
                              excludeFromTotal: !account.excludeFromTotal,
                            );
                            try {
                              await ref
                                  .read(accountProvider.notifier)
                                  .updateAccount(updatedAccount);
                              HapticService.selection();
                            } catch (_) {
                              if (context.mounted) {
                                KoinSnackBar.error(
                                  context,
                                  'Could not update account inclusion',
                                  subtitle: 'Try again.',
                                );
                              }
                            }
                          },
                        );

                        if (showEntranceAnimations) {
                          accountItem = accountItem
                              .koinAnimate(
                                context,
                                autoPlay: !MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                                onInit: KoinMotion.onInit(context),
                              )
                              .fade(delay: (index * 60).ms, duration: 400.ms)
                              .slideY(
                                begin: 0.1,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              );
                        }

                        return (
                          id: account.id,
                          child: SwipeToDeleteTile(
                            key: Key('dismiss_${account.id}'),
                            borderRadius: BorderRadius.circular(
                              KoinShape.field,
                            ),
                            fillRoundedCorners: true,
                            backgroundColor: AppTheme.errorColor(context),
                            icon: Icons.delete_rounded,
                            confirmTitle: 'Delete Account?',
                            confirmDescription: 'All transactions associated with this account will be unlinked. This cannot be undone.',
                            onDelete: () async {
                              HapticService.heavy();
                              await ref
                                  .read(accountProvider.notifier)
                                  .deleteAccount(account.id);
                            },
                            child: accountItem,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          KoinErrorState(onRetry: () => ref.invalidate(accountProvider)),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    final button = Tooltip(
      message: 'Add new account',
      excludeFromSemantics: true,
      child: KoinAddButton(
        label: 'Add account',
        stacked: true,
        borderRadius: KoinShape.field,
        onPressed: () {
          Navigator.push(
            context,
            SlideUpRoute(page: const AccountFormScreen()),
          );
        },
      ),
    );

    if (showEntranceAnimations) {
      return button
          .koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fade(duration: 250.ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: 250.ms,
            curve: Curves.easeOutCubic,
          );
    }
    return button;
  }

  Widget _buildEmptyState(BuildContext context) => KoinEmptyState.sliver(
    icon: Icons.account_balance_wallet_rounded,
    title: 'No accounts yet',
    subtitle: 'Add your first account to start tracking your money',
    action: KoinPrimaryButton(
      label: 'Add Account',
      onPressed: () {
        HapticService.medium();
        Navigator.push(context, SlideUpRoute(page: const AccountFormScreen()));
      },
    ),
  );
}
