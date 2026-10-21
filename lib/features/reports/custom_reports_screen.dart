import 'package:flutter/material.dart';

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/reports/report_service.dart';

import 'package:file_picker/file_picker.dart';

import 'dart:io';

class CustomReportsScreen extends ConsumerStatefulWidget {
  const CustomReportsScreen({super.key});

  @override
  ConsumerState<CustomReportsScreen> createState() =>
      _CustomReportsScreenState();
}

class _CustomReportsScreenState extends ConsumerState<CustomReportsScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  TransactionType? _selectedType;
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedAccountIds = {};
  bool _isExporting = false;
  bool get _reportReady =>
      ref.read(transactionProvider).hasValue &&
      !ref.read(transactionProvider).hasError &&
      !ref.read(transactionProvider).isLoading &&
      ref.read(accountProvider).hasValue &&
      !ref.read(accountProvider).hasError &&
      !ref.read(accountProvider).isLoading &&
      ref.read(categoriesProvider).hasValue &&
      !ref.read(categoriesProvider).hasError &&
      !ref.read(categoriesProvider).isLoading;

  TransactionFilter get _currentReportFilter => TransactionFilter(
    dateRange: _dateRange,
    type: _selectedType,
    categoryIds: _selectedCategoryIds,
    accountIds: _selectedAccountIds,
  );

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final currencySymbol = settings.currency.symbol;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                KoinSpacing.screenInset,
                16,
                KoinSpacing.screenInset,
                _stackExportActions(context) ? 280 : 140,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    [
                          _buildHeader(context),
                          const Gap(32),
                          if (!_reportReady) ...[
                            _buildSummaryCard(context, ref, currencySymbol),
                            const Gap(24),
                          ],
                          DateRangeSelector(
                            initialDateRange: _dateRange,
                            onChanged: (range) {
                              if (range != null) {
                                setState(() => _dateRange = range);
                              }
                            },
                          ),
                          const Gap(24),
                          if (_reportReady)
                            _buildSummaryCard(context, ref, currencySymbol),
                          const Gap(KoinSpacing.sectionGap),
                          const KoinSectionHeader(
                            title: 'Transaction Type',
                            subtitle: 'Filter by income or expense',
                          ),
                          const Gap(12),
                          _buildTypeSelector(context),
                          const Gap(KoinSpacing.sectionGap),
                          const KoinSectionHeader(
                            title: 'Categories',
                            subtitle: 'Narrow down by spending categories',
                          ),
                          const Gap(12),
                          _buildCategorySelector(context, categories),
                          const Gap(KoinSpacing.sectionGap),
                          const KoinSectionHeader(
                            title: 'Accounts',
                            subtitle: 'Select specific accounts to include',
                          ),
                          const Gap(12),
                          _buildAccountSelector(context, accounts),
                        ]
                        .koinAnimate(
                          context,
                          autoPlay: !MediaQuery.disableAnimationsOf(context),
                          onInit: KoinMotion.onInit(context),
                          interval: KoinMotion.duration(context, 40.ms),
                        )
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ),
            _buildExportActions(
              context,
              categories,
              accounts,
              currencySymbol,
            ).koinEntrance(context),
            if (_isExporting)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor(context),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    WidgetRef ref,
    String currencySymbol,
  ) {
    final transactionsAsync = ref.watch(transactionProvider);
    final accounts = ref.watch(accountProvider);
    final categories = ref.watch(categoriesProvider);
    if (transactionsAsync.hasError ||
        accounts.hasError ||
        categories.hasError) {
      return KoinErrorState(
        message: 'Could not load report data.',
        onRetry: () {
          ref.invalidate(transactionProvider);
          ref.invalidate(accountProvider);
          ref.invalidate(categoriesProvider);
        },
      );
    }
    if (!_reportReady) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading report data…'),
          ],
        ),
      );
    }

    final filtered = _currentReportFilter.apply(transactionsAsync.value!);
    final totalAmount = filtered.fold(0.0, (sum, tx) => sum + tx.amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
        ),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              context,
              'Transactions',
              filtered.length.toDouble(),
              Icons.receipt_long_rounded,
              AppTheme.primaryColor(context),
              null,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(
              horizontal: KoinSpacing.screenInset,
            ),
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
          Expanded(
            child: _buildSummaryItem(
              context,
              'Total Volume',
              totalAmount,
              Icons.analytics_rounded,
              AppTheme.secondaryColor(context),
              currencySymbol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return KoinPageHeader(
      title: 'Custom Reports',
      padding: const EdgeInsets.symmetric(vertical: 8),
      subtitle: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          'REPORT BUILDER',
          style: TextStyle(
            color: AppTheme.textLightColor(context).withValues(alpha: 0.7),
            fontSize: KoinTypography.overline,
            fontWeight: KoinTypography.titleWeight,
            letterSpacing: KoinTypography.overlineTracking,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    double value,
    IconData icon,
    Color color,
    String? currencySymbol,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: KoinTypography.overline,
                  fontWeight: KoinTypography.labelWeight,
                ),
              ),
              AnimatedCounter(
                value: value,
                formatter: (v) => currencySymbol != null
                    ? ref
                          .read(settingsProvider)
                          .currency
                          .compactFormatter
                          .format(v)
                    : v.toInt().toString(),
                style: TextStyle(
                  color: AppTheme.textColor(context),
                  fontSize: KoinTypography.body,
                  fontWeight: KoinTypography.headingWeight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    const types = [null, TransactionType.expense, TransactionType.income];
    return KoinChoiceControl(
      segments: const [
        KoinSegmentItem(label: 'All'),
        KoinSegmentItem(label: 'Expenses'),
        KoinSegmentItem(label: 'Income'),
      ],
      selectedIndex: types.indexOf(_selectedType),
      onChanged: (index) => setState(() => _selectedType = types[index]),
    );
  }

  Widget _buildCategorySelector(
    BuildContext context,
    List<TransactionCategory> categories,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = _selectedCategoryIds.contains(cat.id);
        return KoinSelectableOption(
          label: cat.name,
          selected: isSelected,
          accentColor: AppTheme.primaryColor(context),
          leading: KoinIconBadge(
            icon: IconUtils.getIcon(cat.iconCodePoint),
            color: cat.color,
            size: 26,
            iconSize: 14,
          ),
          onTap: () {
            HapticService.light();
            setState(() {
              if (isSelected) {
                _selectedCategoryIds.remove(cat.id);
              } else {
                _selectedCategoryIds.add(cat.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildAccountSelector(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accounts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemBuilder: (context, index) {
        final acc = accounts[index];
        final isSelected = _selectedAccountIds.contains(acc.id);
        return KoinSelectableOption(
          label: acc.name,
          selected: isSelected,
          accentColor: AppTheme.secondaryColor(context),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: acc.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: KoinAccountAvatar(
              iconCodePoint: acc.iconCodePoint,
              logoAsset: acc.logoAsset,
              color: acc.color,
              size: 14,
            ),
          ),
          onTap: () {
            HapticService.light();
            setState(() {
              if (isSelected) {
                _selectedAccountIds.remove(acc.id);
              } else {
                _selectedAccountIds.add(acc.id);
              }
            });
          },
        );
      },
    );
  }

  bool _stackExportActions(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 380 ||
      MediaQuery.textScalerOf(context).scale(14) > 20;

  Widget _buildExportActions(
    BuildContext context,
    List<TransactionCategory> categories,
    List<Account> accounts,
    String currencySymbol,
  ) {
    final csv = _buildExportButton(
      context,
      'Export CSV',
      Icons.grid_on_rounded,
      AppTheme.dividerColor(context).withValues(alpha: 0.5),
      AppTheme.textColor(context),
      () => _handleExport(
        context,
        categories,
        accounts,
        currencySymbol,
        isPdf: false,
      ),
    );
    final pdf = _buildExportButton(
      context,
      'Export PDF',
      Icons.picture_as_pdf_rounded,
      AppTheme.primaryColor(context),
      AppTheme.primaryColor(context),
      () => _handleExport(
        context,
        categories,
        accounts,
        currencySymbol,
        isPdf: true,
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              KoinSpacing.screenInset,
              16,
              KoinSpacing.screenInset,
              40,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor(context).withValues(alpha: 0.8),
              border: Border(
                top: BorderSide(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
                ),
              ),
            ),
            child: _stackExportActions(context)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [csv, const Gap(12), pdf],
                  )
                : Row(
                    children: [
                      Expanded(child: csv),
                      const Gap(12),
                      Expanded(child: pdf),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    String label,
    IconData icon,
    Color borderColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    final ready = _reportReady && !_isExporting;
    if (!ready) textColor = textColor.withValues(alpha: 0.45);
    return PressableScale(
      onTap: ready ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const Gap(10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: KoinTypography.titleWeight,
                  fontSize: KoinTypography.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    List<TransactionCategory> categories,
    List<Account> accounts,
    String currencySymbol, {
    required bool isPdf,
  }) async {
    if (_isExporting) return;
    HapticService.medium();

    // Get transactions from provider
    final transactionsAsync = ref.read(transactionProvider);
    if (!_reportReady) {
      KoinSnackBar.info(
        context,
        'Report data is not ready',
        subtitle: 'Wait for loading to finish or retry the failed request.',
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final allTransactions = transactionsAsync.value!;

      // Filter transactions using deep TransactionFilter
      final filteredTransactions = _currentReportFilter.apply(allTransactions);

      if (filteredTransactions.isEmpty) {
        if (mounted) {
          KoinSnackBar.info(
            context,
            'No Data Found',
            subtitle: 'Try adjusting your filters or date range',
          );
        }
        return;
      }

      final payload = await ReportService.generateReport(
        transactions: filteredTransactions,
        categories: categories,
        accounts: accounts,
        currencySymbol: currencySymbol,
        currencyCode: ref.read(settingsProvider).currency.code,
        isPdf: isPdf,
      );

      final Uri? outputUri = await FilePicker.saveFile(
        dialogTitle: 'Select report destination',
        fileName: payload.fileName,
        type: FileType.custom,
        allowedExtensions: [payload.extension],
        bytes: payload.bytes,
      );

      if (outputUri == null) {
        if (mounted) {
          setState(() => _isExporting = false);
        }
        return;
      }

      // Ensure file writing if on desktop or local file scheme
      if (outputUri.scheme == 'file') {
        final File file = File(outputUri.toFilePath());
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(payload.bytes);
        }
      }

      if (!context.mounted) return;
      final String fileName = outputUri.pathSegments.isNotEmpty
          ? outputUri.pathSegments.last
          : payload.fileName;
      KoinSnackBar.success(context, 'Report Saved', subtitle: fileName);
    } catch (e) {
      debugPrint('Export error: $e');
      if (!context.mounted) return;
      KoinSnackBar.error(
        context,
        'Export Failed',
        subtitle: 'Check available storage and folder access, then try again.',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
