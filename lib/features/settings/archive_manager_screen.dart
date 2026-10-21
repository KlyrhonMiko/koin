import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/cards/account_card_layout.dart';

/// Keeps archived entities available to history, reports, and existing schedules.
class ArchiveManagerScreen extends ConsumerStatefulWidget {
  const ArchiveManagerScreen({super.key});

  @override
  ConsumerState<ArchiveManagerScreen> createState() =>
      _ArchiveManagerScreenState();
}

class _ArchiveManagerScreenState extends ConsumerState<ArchiveManagerScreen> {
  bool _archivedOnly = false;
  final _busy = <String>{};
  final _pending = <String>{};

  Future<void> _change(
    String key,
    String name,
    bool archived,
    Future<void> Function() write,
  ) async {
    if (!_pending.add(key)) return;
    try {
      if (!archived) {
        final confirmed = await ConfirmationSheet.show(
          context: context,
          title: 'Archive $name?',
          description: 'History and balances are kept. Existing schedules keep using this item. You can restore it here at any time.',
          confirmLabel: 'Archive',
          confirmColor: AppTheme.primaryColor(context),
          icon: KoinIcons.archive,
        );
        if (confirmed != true || !mounted) return;
      }
      if (!mounted) return;
      setState(() => _busy.add(key));
      await write();
      if (mounted) {
        KoinSnackBar.success(
          context,
          archived ? '$name restored' : '$name archived',
        );
      }
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not update $name',
          subtitle: 'Try again.',
        );
      }
    } finally {
      _pending.remove(key);
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Widget? _progress(String key) => _busy.contains(key)
      ? const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      : null;

  double _savingsAmount(Account account) =>
      (ref.watch(savingsGoalsProvider).value ?? [])
          .where(
            (g) =>
                g.linkedAccountId == account.id &&
                g.includeInDashboardBalance &&
                g.currentAmount > 0,
          )
          .fold<double>(0, (sum, g) => sum + g.currentAmount);

  Widget _accountCard(Account account) {
    final currency = ref.watch(settingsProvider).currency;
    final balance =
        ref.watch(dashboardAccountBalancesProvider)[account.id] ??
        account.initialBalance;
    Future<void> write() => ref
        .read(accountProvider.notifier)
        .setArchived(account.id, !account.isArchived);
    return Semantics(
      key: ValueKey('archive_account_${account.id}'),
      hint: account.isArchived ? 'Tap to restore' : 'Tap to archive',
      child: AccountItem(
        compact: true,
        account: account,
        balance: balance,
        savingsAmount: _savingsAmount(account),
        currencySymbol: currency.symbol,
        currency: currency,
        onTap: () => _change(
          'account_${account.id}',
          account.name,
          account.isArchived,
          write,
        ),
        trailing: _progress('account_${account.id}'),
      ),
    );
  }

  Widget _accountsGrid(List<Account> accounts) => LayoutBuilder(
    builder: (context, constraints) {
      final transactions = ref.watch(transactionProvider);
      if (transactions.hasError) {
        return KoinErrorState(
          onRetry: () => ref.invalidate(transactionProvider),
        );
      }
      if (!transactions.hasValue) {
        return const Center(child: CircularProgressIndicator());
      }
      final width = constraints.maxWidth - KoinSpacing.screenInset * 2;
      final largeText = MediaQuery.textScalerOf(context).scale(13) > 19.5;
      final columns = width < 280 || largeText ? 1 : 2;
      final height =
          AccountCardLayout.minimumHeight(context) +
          (accounts.any((a) => !a.excludeFromTotal && _savingsAmount(a) > 0)
              ? 2 +
                    MediaQuery.textScalerOf(context)
                            .scale(KoinTypography.small) *
                        1.5
              : 0);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          KoinSpacing.screenInset,
          12,
          KoinSpacing.screenInset,
          24,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: KoinSpacing.cardGap,
          mainAxisSpacing: KoinSpacing.cardGap,
          mainAxisExtent: height,
        ),
        itemCount: accounts.length,
        itemBuilder: (_, index) => _accountCard(accounts[index]),
      );
    },
  );

  Widget _categoryCard(TransactionCategory category) {
    Future<void> write() => ref
        .read(categoriesProvider.notifier)
        .setArchived(category.id, !category.isArchived);
    return Semantics(
      key: ValueKey('archive_category_${category.id}'),
      hint: category.isArchived ? 'Tap to restore' : 'Tap to archive',
      child: CategoryItem(
        category: category,
        currency: ref.watch(settingsProvider).currency,
        onTap: () => _change(
          'category_${category.id}',
          category.name,
          category.isArchived,
          write,
        ),
        trailing:
            _progress('category_${category.id}') ?? const SizedBox.shrink(),
      ),
    );
  }

  Widget _list<T>(
    AsyncValue<List<T>> state,
    bool Function(T) archived,
    Widget Function(T) row,
    VoidCallback retry, {
    Widget Function(List<T>)? layout,
  }) => state.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => KoinErrorState(onRetry: retry),
    data: (items) {
      final visible = items
          .where((item) => archived(item) == _archivedOnly)
          .toList();
      if (visible.isEmpty) {
        return Center(
          child: Text(_archivedOnly ? 'No archived items' : 'No active items'),
        );
      }
      if (layout != null) return layout(visible);
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          KoinSpacing.screenInset,
          12,
          KoinSpacing.screenInset,
          24,
        ),
        itemCount: visible.length,
        itemBuilder: (_, index) => row(visible[index]),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider);
    final categories = ref.watch(categoriesProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Archive manager'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Accounts'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(KoinSpacing.screenInset),
              child: Text(
                _archivedOnly
                    ? 'Tap a card to restore it to your entry choices.'
                    : 'Tap a card to archive it. History and balances are kept.',
                style: TextStyle(color: AppTheme.textLightColor(context)),
              ),
            ),
            SwitchListTile(
              title: const Text('Show archived items'),
              value: _archivedOnly,
              onChanged: (value) => setState(() => _archivedOnly = value),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _list<Account>(
                    accounts,
                    (item) => item.isArchived,
                    _accountCard,
                    () => ref.invalidate(accountProvider),
                    layout: _accountsGrid,
                  ),
                  _list<TransactionCategory>(
                    categories,
                    (item) => item.isArchived,
                    _categoryCard,
                    () => ref.invalidate(categoriesProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
