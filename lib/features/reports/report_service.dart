import 'package:koin/core/utils/icon_utils.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' as painting;
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle, FontLoader;

class ReportSummary {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;

  const ReportSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
  });

  factory ReportSummary.fromTransactions(List<AppTransaction> transactions) {
    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.countsAsIncome) {
        income += tx.amount;
      } else if (tx.countsAsExpense) {
        expense += tx.amount;
      }
    }
    return ReportSummary(
      totalIncome: income,
      totalExpense: expense,
      netBalance: income - expense,
    );
  }
}

class ReportExportPayload {
  final Uint8List bytes;
  final String fileName;
  final String extension;

  const ReportExportPayload({
    required this.bytes,
    required this.fileName,
    required this.extension,
  });
}

class ReportService {
  static Future<void>? _iconFontLoaded;

  /// Render the same bundled Phosphor glyphs used by account/category rows.
  static Future<pw.MemoryImage> _renderIcon(
    int codePoint,
    String colorHex,
  ) async {
    _iconFontLoaded ??=
        (FontLoader('KoinExportIcons')..addFont(
              rootBundle.load(
                'packages/phosphor_icons/lib/fonts/Phosphor-Fill.ttf',
              ),
            ))
            .load();
    await _iconFontLoaded;
    final painter = painting.TextPainter(
      text: painting.TextSpan(
        text: String.fromCharCode(IconUtils.getIcon(codePoint).codePoint),
        style: painting.TextStyle(
          fontFamily: 'KoinExportIcons',
          fontSize: 64,
          color: ui.Color(
            int.parse(colorHex.replaceFirst('#', 'FF'), radix: 16),
          ),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final recorder = ui.PictureRecorder();
    painter.paint(
      ui.Canvas(recorder),
      ui.Offset((80 - painter.width) / 2, (80 - painter.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(80, 80);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return pw.MemoryImage(data!.buffer.asUint8List());
    } finally {
      image.dispose();
      picture.dispose();
      painter.dispose();
    }
  }

  static Future<ReportExportPayload> generateReport({
    required List<AppTransaction> transactions,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    required String currencySymbol,
    String? currencyCode,
    required bool isPdf,
    String title = 'Custom Financial Report',
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final timeStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    if (isPdf) {
      final bytes = await generatePDF(
        transactions: transactions,
        categories: categories,
        accounts: accounts,
        title: title,
        currencySymbol: currencySymbol,
        currencyCode: currencyCode,
      );
      return ReportExportPayload(
        bytes: bytes,
        fileName: 'Koin_Report_$timeStr.pdf',
        extension: 'pdf',
      );
    } else {
      final bytes = await generateCSV(
        transactions: transactions,
        categories: categories,
        accounts: accounts,
        currencyCode: currencyCode,
      );
      return ReportExportPayload(
        bytes: bytes,
        fileName: 'Koin_Report_$timeStr.csv',
        extension: 'csv',
      );
    }
  }

  /// Spreadsheet applications evaluate formula prefixes even in quoted CSV.
  /// Prefix text cells only; amount columns retain their numeric type.
  static String _spreadsheetText(String value) {
    final candidate = value.trimLeft();
    if (RegExp(r'^[=+@-]').hasMatch(candidate) ||
        value.startsWith('\t') ||
        value.startsWith('\r') ||
        value.startsWith('\n')) {
      return "'$value";
    }
    return value;
  }

  static Future<Uint8List> generateCSV({
    required List<AppTransaction> transactions,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    String? currencyCode,
  }) async {
    List<List<dynamic>> rows = [];

    // Header: Date, Amount, Type, Category, Account, To Account, Note
    rows.add([
      'Date',
      'Amount',
      'Type',
      'Category',
      'Account',
      'To Account',
      'Note',
      'Currency',
    ]);

    for (var tx in transactions) {
      String categoryName;
      if (tx.isDebtTransfer) {
        categoryName = 'Loan';
      } else if (tx.type == TransactionType.transfer) {
        categoryName = 'Transfer';
      } else {
        final category = categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => TransactionCategory(
            id: 'unknown',
            name: 'Unknown category',
            iconCodePoint: 0,
            colorHex: '#000000',
            type: tx.type,
          ),
        );
        categoryName = category.name;
      }

      final account = accounts.firstWhere(
        (a) => a.id == tx.accountId,
        orElse: () => Account(
          id: 'unknown',
          name: 'Unlinked account',
          iconCodePoint: 0,
          colorHex: '#000000',
        ),
      );

      String toAccountName = '';
      if (tx.type == TransactionType.transfer && tx.toAccountId != null) {
        final toAccount = accounts.firstWhere(
          (a) => a.id == tx.toAccountId,
          orElse: () => Account(
            id: 'unknown',
            name: 'Unlinked account',
            iconCodePoint: 0,
            colorHex: '#000000',
          ),
        );
        toAccountName = toAccount.name;
      }

      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
        tx.amount,
        tx.isDebtTransfer
            ? (tx.type == TransactionType.income
                  ? 'LOAN_REPAYMENT'
                  : 'LOAN_OUT')
            : tx.type.name.toUpperCase(),
        _spreadsheetText(categoryName),
        _spreadsheetText(account.name),
        _spreadsheetText(toAccountName),
        _spreadsheetText(tx.note),
        currencyCode ?? '',
      ]);
    }

    final String csvContent = csv.encode(rows);
    return Uint8List.fromList(utf8.encode(csvContent));
  }

  static Future<Uint8List> generatePDF({
    required List<AppTransaction> transactions,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    required String title,
    required String currencySymbol,
    String? currencyCode,
  }) async {
    final usedCategoryIds = transactions.map((tx) => tx.categoryId).toSet();
    final usedAccountIds = transactions.map((tx) => tx.accountId).toSet();
    final iconKeys = {
      for (final category in categories)
        if (usedCategoryIds.contains(category.id) &&
            category.iconCodePoint != 0)
          (category.iconCodePoint, category.colorHex),
      for (final account in accounts)
        if (usedAccountIds.contains(account.id) && account.iconCodePoint != 0)
          (account.iconCodePoint, account.colorHex),
    };
    final iconImages = <(int, String), pw.MemoryImage>{};
    for (final key in iconKeys) {
      iconImages[key] = await _renderIcon(key.$1, key.$2);
    }

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/outfit/Outfit-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/outfit/Outfit-Bold.ttf'),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final money = NumberFormat.currency(
      name: currencyCode,
      symbol: _sanitizeCurrency(currencySymbol, currencyCode),
      decimalDigits: currencyCode == null
          ? 2
          : NumberFormat.currency(name: currencyCode).decimalDigits,
    );

    // Reports retain the brand palette with readable foregrounds on paper.
    final primaryColor = PdfColor.fromInt(0xFF007A5D);
    final incomeColor = PdfColor.fromInt(0xFF007A5D);
    final expenseColor = PdfColor.fromInt(0xFFB42332);
    final transferColor = PdfColor.fromInt(0xFF1D4ED8);
    final textColor = PdfColor.fromInt(0xFF1A1A1A);
    final textLightColor = PdfColor.fromInt(0xFF6B7280);
    final greyColor = PdfColor.fromInt(0xFFF1F3F5);

    // Calculate Summary using domain model
    final summary = ReportSummary.fromTransactions(transactions);
    final totalIncome = summary.totalIncome;
    final totalExpense = summary.totalExpense;
    final netBalance = summary.netBalance;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            'Koin Financial Report',
            style: pw.TextStyle(
              color: textLightColor,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(color: textLightColor, fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(color: textLightColor, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Header Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'K',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Koin Financial',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                    style: pw.TextStyle(color: textLightColor, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Summary Section
          pw.Row(
            children: [
              _buildSummaryCard(
                'TOTAL INCOME',
                money.format(totalIncome),
                incomeColor,
              ),
              pw.SizedBox(width: 16),
              _buildSummaryCard(
                'TOTAL EXPENSE',
                money.format(totalExpense),
                expenseColor,
              ),
              pw.SizedBox(width: 16),
              _buildSummaryCard(
                'NET BALANCE',
                money.format(netBalance),
                netBalance >= 0 ? incomeColor : expenseColor,
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // Transactions Table
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Date
              1: const pw.FlexColumnWidth(3), // Category
              2: const pw.FlexColumnWidth(3), // Account
              3: const pw.FlexColumnWidth(4), // Note
              4: const pw.FlexColumnWidth(2.5), // Amount
            },
            border: null,
            children: [
              // Table Header
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.vertical(
                    top: pw.Radius.circular(8),
                  ),
                ),
                children: [
                  _buildHeaderCell('Date'),
                  _buildHeaderCell('Category'),
                  _buildHeaderCell('Account'),
                  _buildHeaderCell('Note'),
                  _buildHeaderCell('Amount', align: pw.Alignment.centerRight),
                ],
              ),
              // Table Body
              ...transactions.asMap().entries.map((entry) {
                final tx = entry.value;
                final index = entry.key;
                final isLast = index == transactions.length - 1;

                final category = categories.firstWhere(
                  (c) => c.id == tx.categoryId,
                  orElse: () => TransactionCategory(
                    id: '',
                    name: tx.type == TransactionType.transfer
                        ? 'Transfer'
                        : 'Unknown category',
                    iconCodePoint: 0,
                    colorHex: '#64748B',
                    type: tx.type,
                  ),
                );

                final account = accounts.firstWhere(
                  (a) => a.id == tx.accountId,
                  orElse: () => Account(
                    id: '',
                    name: 'Unlinked account',
                    iconCodePoint: 0,
                    colorHex: '#64748B',
                  ),
                );

                String accountDisplay = account.name;
                if (tx.type == TransactionType.transfer &&
                    tx.toAccountId != null) {
                  final toAccount = accounts.firstWhere(
                    (a) => a.id == tx.toAccountId,
                    orElse: () => Account(
                      id: '',
                      name: 'Unlinked account',
                      iconCodePoint: 0,
                      colorHex: '#64748B',
                    ),
                  );
                  accountDisplay = '${account.name} -> ${toAccount.name}';
                }

                final amountColor = tx.type == TransactionType.income
                    ? incomeColor
                    : (tx.type == TransactionType.expense
                          ? expenseColor
                          : transferColor);

                final amountPrefix = tx.type == TransactionType.income
                    ? '+'
                    : (tx.type == TransactionType.expense ? '-' : '');

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: index % 2 == 0 ? PdfColors.white : greyColor,
                    borderRadius: isLast
                        ? const pw.BorderRadius.vertical(
                            bottom: pw.Radius.circular(8),
                          )
                        : null,
                  ),
                  children: [
                    _buildDataCell(DateFormat('MMM dd, HH:mm').format(tx.date)),
                    _buildIconCell(
                      tx.isDebtTransfer
                          ? 'Loan'
                          : tx.type == TransactionType.transfer
                          ? 'Transfer'
                          : category.name,
                      PdfColor.fromHex(category.colorHex),
                      tx.type == TransactionType.transfer
                          ? null
                          : iconImages[(
                              category.iconCodePoint,
                              category.colorHex,
                            )],
                    ),
                    _buildIconCell(
                      accountDisplay,
                      PdfColor.fromHex(account.colorHex),
                      iconImages[(account.iconCodePoint, account.colorHex)],
                    ),
                    _buildDataCell(tx.note.isEmpty ? '-' : tx.note),
                    _buildDataCell(
                      '$amountPrefix${money.format(tx.amount)}',
                      color: amountColor,
                      align: pw.Alignment.centerRight,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryCard(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey200, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF6B7280),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Container(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Container(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            color: color ?? PdfColor.fromInt(0xFF1A1A1A),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildIconCell(
    String text,
    PdfColor color,
    pw.MemoryImage? iconImage,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (iconImage != null)
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                color: PdfColor(
                  0.9 + color.red * 0.1,
                  0.9 + color.green * 0.1,
                  0.9 + color.blue * 0.1,
                ),
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(child: pw.Image(iconImage, width: 9, height: 9)),
            ),
          pw.SizedBox(width: iconImage != null ? 6 : 0),
          pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static String _sanitizeCurrency(String symbol, [String? code]) {
    if (code != null) return '$code ';
    // Map problematic symbols to safe alternatives that are universally supported.
    final map = {
      '₹': 'INR ',
      '₱': 'PHP ',
      '€': 'EUR ',
      '£': 'GBP ',
      '¥': '¥',
      '\$': '\$',
    };
    return map[symbol] ?? symbol;
  }
}
