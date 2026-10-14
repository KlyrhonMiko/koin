import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/reports/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'actual primary labels and icons contrast across accent palettes',
    (tester) async {
      for (final dark in [false, true]) {
        for (final accent in AppTheme.accentColors) {
          final theme = AppTheme.getTheme(accent, dark);
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$dark-$accent'),
              theme: theme,
              home: Scaffold(
                body: KoinPrimaryButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: () {},
                ),
              ),
            ),
          );
          final text = tester.widget<Text>(find.text('Save'));
          final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
          expect(icon.color, text.style!.color);
          final context = tester.element(find.byType(KoinPrimaryButton));
          for (final stop in AppTheme.primaryGradient(context).colors) {
            final background = Color.alphaBlend(
              stop,
              theme.colorScheme.surface,
            );
            expect(
              AppTheme.contrast(text.style!.color!, background),
              greaterThanOrEqualTo(4.5),
              reason: '$dark / $accent / $stop',
            );
          }
          expect(
            AppTheme.contrast(theme.colorScheme.onPrimary, accent),
            greaterThanOrEqualTo(4.5),
          );
          for (final content in [
            AppTheme.incomeContentColor(context),
            AppTheme.expenseContentColor(context),
            AppTheme.transferContentColor(context),
            AppTheme.errorContentColor(context),
          ]) {
            expect(
              AppTheme.contrast(content, AppTheme.surfaceLightColor(context)),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'PDF export embeds Outfit and renders bundled Material icon glyphs',
    () async {
      final bytes = await ReportService.generatePDF(
        transactions: [
          AppTransaction(
            id: 'expense',
            amount: 125.50,
            date: DateTime(2026, 10, 14, 9, 30),
            type: TransactionType.expense,
            categoryId: 'food',
            accountId: 'cash',
            note: 'Lunch with friends',
          ),
          AppTransaction(
            id: 'income',
            amount: 2400,
            date: DateTime(2026, 10, 14, 8),
            type: TransactionType.income,
            categoryId: 'salary',
            accountId: 'cash',
          ),
        ],
        categories: [
          TransactionCategory(
            id: 'food',
            name: 'Food',
            iconCodePoint: Icons.restaurant.codePoint,
            colorHex: '#00D09E',
            type: TransactionType.expense,
          ),
          TransactionCategory(
            id: 'salary',
            name: 'Salary',
            iconCodePoint: Icons.work.codePoint,
            colorHex: '#00D09E',
            type: TransactionType.income,
          ),
        ],
        accounts: [
          Account(
            id: 'cash',
            name: 'Cash',
            initialBalance: 5000,
            iconCodePoint: Icons.payments_rounded.codePoint,
            colorHex: '#00D09E',
          ),
        ],
        title: 'Consistency preview',
        currencySymbol: '₱',
        currencyCode: 'PHP',
      );
      final document = latin1.decode(bytes);
      expect(document, startsWith('%PDF'));
      expect(document, contains('Outfit'));
      expect(document.contains(RegExp(r'/Subtype\s*/Image')), isTrue);
      expect(document, contains('/FontFile2'));
      if (const bool.fromEnvironment('UI_PREVIEWS')) {
        await Directory('build/consistency_previews').create(recursive: true);
        await File('build/consistency_previews/report.pdf').writeAsBytes(bytes);
      }
    },
  );
}
