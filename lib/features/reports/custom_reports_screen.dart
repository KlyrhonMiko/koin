import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/koin_back_button.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

import 'package:koin/features/reports/report_service.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/core/utils/snackbar_utils.dart';

import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context)
                      .animate()
                      .fade(duration: 500.ms)
                      .slideY(begin: -0.1, curve: Curves.easeOutCubic),
                  const Gap(32),
                  _buildDateSelector(context)
                      .animate()
                      .fade(delay: 100.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const Gap(24),
                  _buildSummaryCard(context, ref, currencySymbol)
                      .animate()
                      .fade(delay: 150.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const Gap(28),
                  _buildSectionHeader(
                    'Transaction Type',
                  ).animate().fade(delay: 200.ms, duration: 500.ms),
                  const Gap(12),
                  _buildTypeSelector(context)
                      .animate()
                      .fade(delay: 250.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const Gap(28),
                  _buildSectionHeader(
                    'Categories',
                  ).animate().fade(delay: 300.ms, duration: 500.ms),
                  const Gap(12),
                  _buildCategorySelector(context, categories)
                      .animate()
                      .fade(delay: 350.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                  const Gap(28),
                  _buildSectionHeader(
                    'Accounts',
                  ).animate().fade(delay: 400.ms, duration: 500.ms),
                  const Gap(12),
                  _buildAccountSelector(context, accounts)
                      .animate()
                      .fade(delay: 450.ms, duration: 500.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                ],
              ),
            ),
            _buildSummaryCard(context, ref, currencySymbol, getCountOnly: true)
                .animate()
                .fade(delay: 600.ms, duration: 500.ms)
                .slideY(begin: 0.2, curve: Curves.easeOutCubic),
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
    String currencySymbol, {
    bool getCountOnly = false,
  }) {
    final transactionsAsync = ref.watch(transactionProvider);
    if (transactionsAsync.value == null) return const SizedBox.shrink();

    final filtered = transactionsAsync.value!.where((tx) {
      final dateInRange =
          tx.date.isAfter(
            _dateRange.start.subtract(const Duration(seconds: 1)),
          ) &&
          tx.date.isBefore(_dateRange.end.add(const Duration(days: 1)));
      if (!dateInRange) return false;
      if (_selectedType != null && tx.type != _selectedType) return false;
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(tx.categoryId)) {
        return false;
      }
      if (_selectedAccountIds.isNotEmpty &&
          !_selectedAccountIds.contains(tx.accountId)) {
        return false;
      }
      return true;
    }).toList();

    if (getCountOnly) {
      return _buildExportActions(
        context,
        ref.watch(categoriesProvider).value ?? [],
        ref.watch(accountProvider).value ?? [],
        currencySymbol,
        filtered.length,
      );
    }

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
          BoxShadow(
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
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const KoinBackButton(),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REPORT BUILDER',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Gap(2),
                Text(
                  'Custom Reports',
                  style: TextStyle(
                    color: AppTheme.textColor(context),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: AppTheme.textColor(context),
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return PressableScale(
      onTap: () async {
        HapticService.light();
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: _dateRange,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppTheme.primaryColor(context),
                  primary: AppTheme.primaryColor(context),
                  onPrimary: Colors.white,
                  surface: AppTheme.surfaceColor(context),
                  onSurface: AppTheme.textColor(context),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _dateRange = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor(context).withValues(alpha: 0.05),
              AppTheme.primaryColor(context).withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.primaryColor(context).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.calendar_month_rounded,
                size: 100,
                color: AppTheme.primaryColor(context).withValues(alpha: 0.05),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor(
                          context,
                        ).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Gap(20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Period',
                        style: TextStyle(
                          color: AppTheme.textLightColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        '${DateFormat('MMM d').format(_dateRange.start)} — ${DateFormat('MMM d, yyyy').format(_dateRange.end)}',
                        style: TextStyle(
                          color: AppTheme.textColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.5),
                  size: 14,
                ),
              ],
            ),
          ],
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedCounter(
                value: value,
                formatter: (v) => currencySymbol != null
                    ? NumberFormat.compactCurrency(
                        symbol: currencySymbol,
                      ).format(v)
                    : v.toInt().toString(),
                style: TextStyle(
                  color: AppTheme.textColor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          _buildTypeChip(null, 'All'),
          _buildTypeChip(TransactionType.expense, 'Expenses'),
          _buildTypeChip(TransactionType.income, 'Income'),
        ],
      ),
    );
  }

  Widget _buildTypeChip(TransactionType? type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: PressableScale(
        enableHaptic: false,
        onTap: () {
          HapticService.selection();
          setState(() => _selectedType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor(
                        context,
                      ).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textColor(context),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
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
        return PressableScale(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor(context).withValues(alpha: 0.1)
                  : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor(context)
                    : AppTheme.dividerColor(context).withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconUtils.getIcon(cat.iconCodePoint),
                    color: cat.color,
                    size: 14,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryColor(context),
                    size: 14,
                  ),
              ],
            ),
          ),
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
        return PressableScale(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.secondaryColor(context).withValues(alpha: 0.1)
                  : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.secondaryColor(context)
                    : AppTheme.dividerColor(context).withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: acc.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconUtils.getIcon(acc.iconCodePoint),
                    color: acc.color,
                    size: 14,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    acc.name,
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.secondaryColor(context),
                    size: 14,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportActions(
    BuildContext context,
    List<TransactionCategory> categories,
    List<Account> accounts,
    String currencySymbol,
    int transactionCount,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.backgroundColor(context).withValues(alpha: 0.7),
                  AppTheme.backgroundColor(context).withValues(alpha: 0.95),
                  AppTheme.backgroundColor(context),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildExportButton(
                    context,
                    'CSV',
                    '($transactionCount)',
                    Icons.grid_on_rounded,
                    const LinearGradient(
                      colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    () => _handleExport(
                      context,
                      categories,
                      accounts,
                      currencySymbol,
                      isPdf: false,
                    ),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: _buildExportButton(
                    context,
                    'PDF',
                    'Report',
                    Icons.picture_as_pdf_rounded,
                    LinearGradient(
                      colors: [
                        AppTheme.primaryColor(context),
                        AppTheme.primaryColor(context).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    () => _handleExport(
                      context,
                      categories,
                      accounts,
                      currencySymbol,
                      isPdf: true,
                    ),
                  ),
                ),
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
    String subLabel,
    IconData icon,
    Gradient gradient,
    VoidCallback onTap,
  ) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withValues(
                alpha: 0.3,
              ),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.1),
                size: 60,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const Gap(12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        subLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
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
    HapticService.medium();

    // Get transactions from provider
    final transactionsAsync = ref.read(transactionProvider);
    if (transactionsAsync.value == null) return;

    setState(() => _isExporting = true);

    try {
      final allTransactions = transactionsAsync.value!;

      // Filter transactions
      final filteredTransactions = allTransactions.where((tx) {
        final dateInRange =
            tx.date.isAfter(
              _dateRange.start.subtract(const Duration(seconds: 1)),
            ) &&
            tx.date.isBefore(_dateRange.end.add(const Duration(days: 1)));
        if (!dateInRange) return false;

        if (_selectedType != null && tx.type != _selectedType) return false;

        if (_selectedCategoryIds.isNotEmpty &&
            !_selectedCategoryIds.contains(tx.categoryId)) {
          return false;
        }

        if (_selectedAccountIds.isNotEmpty &&
            !_selectedAccountIds.contains(tx.accountId)) {
          return false;
        }

        return true;
      }).toList();

      if (filteredTransactions.isEmpty) {
        if (mounted) {
          KoinSnackBar.info(
            context,
            'No transactions found for the selected filters',
          );
        }
        return;
      }

      Uint8List bytes;
      String defaultFileName;
      String extension;

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (isPdf) {
        bytes = await ReportService.generatePDF(
          transactions: filteredTransactions,
          categories: categories,
          accounts: accounts,
          title: 'Custom Financial Report',
          currencySymbol: currencySymbol,
        );
        defaultFileName = 'Koin_Report_$timestamp.pdf';
        extension = 'pdf';
      } else {
        bytes = await ReportService.generateCSV(
          transactions: filteredTransactions,
          categories: categories,
          accounts: accounts,
        );
        defaultFileName = 'Koin_Report_$timestamp.csv';
        extension = 'csv';
      }

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select report destination',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );

      if (outputPath == null) {
        if (mounted) {
          setState(() => _isExporting = false);
        }
        return;
      }

      // On Desktop, FilePicker only returns the path, so we must write manually.
      // On Mobile (Android/iOS), providing bytes to saveFile already saves the file.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final File file = File(outputPath);
        await file.writeAsBytes(bytes);
      }

      if (!context.mounted) return;
      final String fileName = outputPath.split('/').last.split('\\').last;
      KoinSnackBar.success(context, 'Report Saved', subtitle: fileName);
    } catch (e) {
      debugPrint('Export error: $e');
      if (!context.mounted) return;
      KoinSnackBar.error(context, 'Failed to export: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
