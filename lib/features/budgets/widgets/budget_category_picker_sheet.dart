import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';

/// A staged selection: applying categories does not save the budget itself.
class BudgetCategoryPickerSheet extends ConsumerStatefulWidget {
  const BudgetCategoryPickerSheet({
    super.key,
    required this.selectedIds,
    this.continueToLimit = false,
  });

  final Set<String> selectedIds;
  final bool continueToLimit;

  static Future<Set<String>?> show(
    BuildContext context, {
    required Set<String> selectedIds,
    bool continueToLimit = false,
  }) => showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BudgetCategoryPickerSheet(
      selectedIds: selectedIds,
      continueToLimit: continueToLimit,
    ),
  );

  @override
  ConsumerState<BudgetCategoryPickerSheet> createState() =>
      _BudgetCategoryPickerSheetState();
}

class _BudgetCategoryPickerSheetState
    extends ConsumerState<BudgetCategoryPickerSheet> {
  late final Set<String> _selected = {...widget.selectedIds};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: KoinSheetSurface(
            height:
                (constraints.maxHeight - keyboard) * (keyboard > 0 ? 1 : .85),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const KoinBottomSheetHandle(
                                padding: EdgeInsets.only(top: 12),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KoinSpacing.screenInset,
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Choose categories',
                                        style: TextStyle(
                                          fontSize: KoinTypography.sectionTitle,
                                          fontWeight:
                                              KoinTypography.headingWeight,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Cancel category selection',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(KoinIcons.x),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KoinSpacing.screenInset,
                                ),
                                child: Text(
                                  'One monthly limit for everything you select.',
                                  style: TextStyle(
                                    fontSize: KoinTypography.caption,
                                    color: AppTheme.textLightColor(context),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KoinSpacing.screenInset,
                                ),
                                child: KoinSearchField(
                                  inline: true,
                                  hintText: 'Search categories',
                                  onChanged: (query) => setState(
                                    () => _query = query.trim().toLowerCase(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        categories.when(
                          loading: () => const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, _) => SliverFillRemaining(
                            hasScrollBody: false,
                            child: KoinErrorState(
                              message: 'Could not load categories.',
                              onRetry: () => ref.invalidate(categoriesProvider),
                            ),
                          ),
                          data: (all) {
                            final expenses = all
                                .where(
                                  (c) =>
                                      c.type == TransactionType.expense &&
                                      (!c.isArchived ||
                                          widget.selectedIds.contains(c.id)),
                                )
                                .toList();
                            final visible = expenses
                                .where(
                                  (c) => c.name.toLowerCase().contains(_query),
                                )
                                .toList();
                            if (visible.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    _query.isEmpty
                                        ? 'Create an expense category to set a budget.'
                                        : 'No matching categories',
                                  ),
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KoinSpacing.screenInset,
                              ),
                              sliver: SliverList.builder(
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final category = visible[index];
                                  final budget = all
                                      .where(
                                        (c) =>
                                            c.hasBudget &&
                                            (c.id == category.id ||
                                                c.sharedBudgetCategoryIds
                                                    .contains(category.id)),
                                      )
                                      .firstOrNull;
                                  return Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      key: ValueKey(
                                        'budget_category_${category.id}',
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      secondary: KoinIconBadge(
                                        icon: IconUtils.getIcon(
                                          category.iconCodePoint,
                                        ),
                                        color: category.color,
                                        size: 36,
                                        radius: 10,
                                      ),
                                      title: Text(
                                        category.name,
                                        style: const TextStyle(
                                          fontSize: KoinTypography.body,
                                          fontWeight:
                                              KoinTypography.labelWeight,
                                        ),
                                      ),
                                      subtitle: budget == null
                                          ? null
                                          : Text(
                                              'In ${[budget, ...expenses.where((c) => c.id != budget.id && budget.sharedBudgetCategoryIds.contains(c.id))].map((c) => c.name).join(' + ')} budget',
                                            ),
                                      value: _selected.contains(category.id),
                                      onChanged: (selected) => setState(() {
                                        HapticService.selection();
                                        if (selected == true) {
                                          _selected.add(category.id);
                                        } else {
                                          _selected.remove(category.id);
                                        }
                                      }),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(KoinSpacing.screenInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${_selected.length} ${_selected.length == 1 ? 'category' : 'categories'} selected',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: KoinTypography.small,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                        const Gap(8),
                        KoinPrimaryButton(
                          label: widget.continueToLimit
                              ? 'Continue'
                              : 'Apply categories',
                          enabled:
                              _selected.isNotEmpty &&
                              categories.hasValue &&
                              !categories.hasError &&
                              !categories.isLoading,
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final available = categories.value!
                                .where((c) => c.type == TransactionType.expense)
                                .map((c) => c.id)
                                .toSet();
                            final selected = _selected.intersection(available);
                            if (selected.isNotEmpty) {
                              Navigator.pop(context, selected);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
