import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/account.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class ReportService {
  static Future<Uint8List> generateCSV({
    required List<AppTransaction> transactions,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
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
    ]);

    for (var tx in transactions) {
      String categoryName;
      if (tx.type == TransactionType.transfer) {
        categoryName = 'Transfer';
      } else {
        final category = categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => TransactionCategory(
            id: 'unknown',
            name: 'Unknown',
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
          name: 'Unknown',
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
            name: 'Unknown',
            iconCodePoint: 0,
            colorHex: '#000000',
          ),
        );
        toAccountName = toAccount.name;
      }

      rows.add([
        DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
        tx.amount,
        tx.type.name.toUpperCase(),
        categoryName,
        account.name,
        toAccountName,
        tx.note,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(csv.codeUnits);
  }

  static Future<Uint8List> generatePDF({
    required List<AppTransaction> transactions,
    required List<TransactionCategory> categories,
    required List<Account> accounts,
    required String title,
    required String currencySymbol,
  }) async {
    pw.Font? iconFont;

    try {
      // Try to load Material Icons font from the bundled assets
      // This path is standard for Flutter apps using Material Icons
      final iconFontData = await rootBundle.load('MaterialIcons-Regular.ttf');
      iconFont = pw.Font.ttf(iconFontData);
      debugPrint('Material Icons font loaded successfully');
    } catch (e) {
      debugPrint('Error loading Material Icons font: $e');
    }

    final pdf = pw.Document();

    // Define Colors from AppTheme
    final primaryColor = PdfColor.fromInt(0xFF00D09E);
    final incomeColor = PdfColor.fromInt(0xFF00D09E);
    final expenseColor = PdfColor.fromInt(0xFFFF6B6B);
    final transferColor = PdfColor.fromInt(0xFF3B82F6);
    final textColor = PdfColor.fromInt(0xFF1A1A1A);
    final textLightColor = PdfColor.fromInt(0xFF6B7280);
    final greyColor = PdfColor.fromInt(0xFFF1F3F5);

    // Calculate Summary
    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        totalExpense += tx.amount;
      }
    }
    final netBalance = totalIncome - totalExpense;

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
                '${_sanitizeCurrency(currencySymbol)}${totalIncome.toStringAsFixed(2)}',
                incomeColor,
              ),
              pw.SizedBox(width: 16),
              _buildSummaryCard(
                'TOTAL EXPENSE',
                '${_sanitizeCurrency(currencySymbol)}${totalExpense.toStringAsFixed(2)}',
                expenseColor,
              ),
              pw.SizedBox(width: 16),
              _buildSummaryCard(
                'NET BALANCE',
                '${_sanitizeCurrency(currencySymbol)}${netBalance.toStringAsFixed(2)}',
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
                  orElse: () => categories.first,
                );

                final account = accounts.firstWhere(
                  (a) => a.id == tx.accountId,
                  orElse: () => accounts.first,
                );

                String accountDisplay = account.name;
                if (tx.type == TransactionType.transfer &&
                    tx.toAccountId != null) {
                  final toAccount = accounts.firstWhere(
                    (a) => a.id == tx.toAccountId,
                    orElse: () => accounts.first,
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
                      category.name,
                      category.iconCodePoint,
                      PdfColor.fromHex(category.colorHex),
                      iconFont,
                    ),
                    _buildIconCell(
                      accountDisplay,
                      account.iconCodePoint,
                      PdfColor.fromHex(account.colorHex),
                      iconFont,
                    ),
                    _buildDataCell(tx.note.isEmpty ? '-' : tx.note),
                    _buildDataCell(
                      '$amountPrefix${_sanitizeCurrency(currencySymbol)}${tx.amount.toStringAsFixed(2)}',
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
    int iconCodePoint,
    PdfColor color,
    pw.Font? iconFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (iconFont != null)
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                color: PdfColor(color.red, color.green, color.blue, 0.1),
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  String.fromCharCode(iconCodePoint),
                  style: pw.TextStyle(
                    font: iconFont,
                    fontSize: 7,
                    color: color,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: iconFont != null ? 6 : 0),
          pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static String _sanitizeCurrency(String symbol) {
    // Map problematic symbols to safe alternatives that are universally supported.
    final map = {
      '₹': 'INR ',
      '₱': 'PHP ',
      '€': 'EUR ',
      '£': 'GBP ',
      '¥': 'JPY ',
      '\$': '\$',
    };
    return map[symbol] ?? symbol;
  }
}
