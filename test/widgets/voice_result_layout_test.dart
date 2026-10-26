import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/transactions/widgets/voice_input_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecognizedVoice extends VoiceInputNotifier {
  _RecognizedVoice(this.words);
  final String words;
  bool _started = false;

  @override
  VoiceInputState build() => VoiceInputState(lastWords: words);

  @override
  Future<void> startListening() async {
    if (_started) {
      state = VoiceInputState(isListening: true, isAvailable: true);
    }
    _started = true;
  }

  @override
  Future<void> stopListening() async {
    state = state.copyWith(isListening: false);
  }
}

void main() {
  setUpAll(() async {
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    for (final entry in {
      'PhosphorRegular': 'Phosphor.ttf',
      'PhosphorFill': 'Phosphor-Fill.ttf',
    }.entries) {
      await (FontLoader('packages/phosphor_icons/${entry.key}')..addFont(
            rootBundle.load('packages/phosphor_icons/lib/fonts/${entry.value}'),
          ))
          .load();
    }
  });

  for (final (width, height, scale, dark, keyboardInset) in [
    (390.0, 844.0, 1.0, true, 0.0),
    (320.0, 844.0, 1.0, true, 0.0),
    (320.0, 844.0, 1.8, false, 0.0),
    (390.0, 600.0, 1.0, true, 280.0),
    (640.0, 360.0, 1.0, false, 0.0),
  ]) {
    for (final transfer in [false, true]) {
      testWidgets(
        'voice result fits $width × $height at $scale with keyboard $keyboardInset (transfer=$transfer)',
        (tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
          final prefs = await SharedPreferences.getInstance();
          final bank = BankTemplate.templates.firstWhere(
            (b) => b.id == 'gcash',
          );
          final accounts = [
            Account(
              id: 'cash',
              name: 'Cash',
              initialBalance: 1000,
              iconCodePoint: KoinIcons.money.codePoint,
              colorHex: '#00D09E',
            ),
            Account(
              id: 'gcash',
              name: 'GCash household purchases and monthly bills',
              initialBalance: 2500,
              iconCodePoint: bank.iconCodePoint,
              colorHex: bank.colorHex,
              logoAsset: bank.logoAsset,
            ),
          ];
          final words = transfer
              ? 'transfer 50 from Cash to ${accounts.last.name}'
              : 'spent 50 on Food using ${accounts.last.name}';
          final providers = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              accountRepositoryProvider.overrideWithValue(
                InMemoryAccountAdapter(initial: accounts),
              ),
              categoryRepositoryProvider.overrideWithValue(
                InMemoryCategoryAdapter(
                  initial: [
                    TransactionCategory(
                      id: 'food',
                      name: 'Food',
                      type: TransactionType.expense,
                      iconCodePoint: KoinIcons.forkKnife.codePoint,
                      colorHex: '#FFA000',
                    ),
                  ],
                ),
              ),
              ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
              savingsRepositoryProvider.overrideWithValue(
                InMemorySavingsAdapter(
                  initial: [
                    SavingsGoal(
                      id: 'reserved',
                      name: 'Emergency savings',
                      linkedAccountId: 'gcash',
                      currentAmount: 500,
                      startDate: DateTime(2026, 1, 1),
                    ),
                  ],
                ),
              ),
              dashboardStatsProvider.overrideWithValue(
                DashboardStats(
                  totalIncome: 0,
                  totalExpense: 0,
                  currentBalance: 3500,
                  accounts: accounts,
                  accountBalances: {'cash': 1000, 'gcash': 2500},
                  categorySpending: {},
                ),
              ),
              categorySuggesterProvider.overrideWithValue(
                TestStubSuggesterAdapter(),
              ),
              voiceInputProvider.overrideWith(() => _RecognizedVoice(words)),
            ],
          );
          addTearDown(providers.dispose);
          await providers.read(accountProvider.future);
          await providers.read(categoriesProvider.future);
          await providers.read(transactionProvider.future);
          await providers.read(savingsGoalsProvider.future);
          ParsedTransactionData? accepted;
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: providers,
              child: MaterialApp(
                theme: AppTheme.getTheme(Colors.teal, dark),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                    viewInsets: EdgeInsets.only(bottom: keyboardInset),
                  ),
                  child: RepaintBoundary(key: captureKey, child: child!),
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        accepted = await VoiceInputSheet.show(context);
                      },
                      child: const Text('Speak'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Speak'));
          await tester.pumpAndSettle();
          expect(find.text('Review transaction'), findsOneWidget);
          expect(find.text("Here's what I got"), findsNothing);
          expect(tester.takeException(), isNull);

          final typeControl = find.byType(TransactionTypeSelector);
          for (final label in ['Expense', 'Income', 'Transfer']) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: typeControl, matching: find.text(label)),
            );
            expect(
              paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              ),
              hasLength(1),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          final bankTile = find.byWidgetPredicate(
            (widget) =>
                widget is SelectionTile &&
                widget.selectedLogoAsset == bank.logoAsset,
          );
          expect(bankTile, findsOneWidget);
          final tile = tester.widget<SelectionTile>(bankTile);
          expect(tile.selectedName, contains(accounts.last.name));
          expect(tile.selectedName, contains(transfer ? '2,500' : '2,000'));
          expect(tile.label, transfer ? 'To' : 'Spendable');
          expect(find.byType(SelectionTile), findsNWidgets(2));
          await tester.runAsync(
            () => precacheImage(
              AssetImage(bank.logoAsset),
              tester.element(bankTile),
            ),
          );
          await tester.pumpAndSettle();

          final capture = Platform.environment['KOIN_CAPTURE_VOICE'];
          if (capture != null) {
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(capture).create(recursive: true);
              await File(
                '$capture/voice-$width-$height-$scale-$keyboardInset-$transfer.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          var expectedAccountId = 'gcash';
          var expectedAmount = 50.0;
          if (width == 320 && scale > 1 && !transfer) {
            await tester.ensureVisible(find.byType(TextField).first);
            await tester.enterText(find.byType(TextField).first, '');
            await tester.ensureVisible(find.text('Use details'));
            await tester.tap(find.text('Use details'));
            await tester.pumpAndSettle();
            expect(find.text('Enter a valid amount'), findsOneWidget);
            expect(accepted, isNull);
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.byType(TextField).first);
            await tester.enterText(find.byType(TextField).first, '50');
            await tester.pumpAndSettle();
          }
          if (width == 390 && height == 844 && !transfer) {
            for (final invalid in ['', '12..3', '0', '-5']) {
              await tester.enterText(find.byType(TextField).first, invalid);
              await tester.ensureVisible(find.text('Use details'));
              await tester.tap(find.text('Use details'));
              await tester.pumpAndSettle();
              expect(accepted, isNull);
              expect(find.text('Review transaction'), findsOneWidget);
              expect(
                find.text(
                  invalid == '' || invalid == '12..3'
                      ? 'Enter a valid amount'
                      : 'Amount must be greater than zero',
                ),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
            }
            await tester.enterText(find.byType(TextField).first, '125.50');
            await tester.enterText(
              find.byType(TextField).last,
              'Lunch with family',
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            expectedAmount = 125.5;
            expect(find.text('Enter a valid amount'), findsNothing);
            expect(find.text('Amount must be greater than zero'), findsNothing);
          }
          if (!transfer && scale == 1 && width == 390) {
            await tester.ensureVisible(bankTile);
            await tester.tap(bankTile);
            await tester.pumpAndSettle();
            final cashCard = find.byWidgetPredicate(
              (widget) => widget is AccountItem && widget.account.id == 'cash',
            );
            await tester.tap(cashCard);
            await tester.pumpAndSettle();
            expect(find.textContaining('Cash •'), findsOneWidget);
            expectedAccountId = 'cash';
          }
          if (width == 640 && transfer) {
            await tester.ensureVisible(find.byTooltip('Close voice review'));
            await tester.tap(find.byTooltip('Close voice review'));
            await tester.pumpAndSettle();
            expect(accepted, isNull);
            expect(find.text('Review transaction'), findsNothing);
            return;
          }
          if (width == 320 && scale == 1 && !transfer) {
            await tester.ensureVisible(find.text('Retry'));
            await tester.tap(find.text('Retry'));
            await tester.pump(const Duration(milliseconds: 250));
            expect(find.text('Listening…'), findsOneWidget);
            expect(providers.read(voiceInputProvider).isListening, isTrue);
            expect(find.text('Review transaction'), findsNothing);
            expect(tester.takeException(), isNull);
            await providers.read(voiceInputProvider.notifier).stopListening();
            await tester.pumpAndSettle();
            return;
          }
          await tester.ensureVisible(find.text('Use details'));
          await tester.tap(find.text('Use details'));
          await tester.pumpAndSettle();
          expect(
            accepted?.type,
            transfer ? TransactionType.transfer : TransactionType.expense,
          );
          expect(accepted?.amount, expectedAmount);
          if (expectedAmount == 125.5) {
            expect(accepted?.note, 'Lunch with family');
          }
          expect(
            transfer ? accepted?.toAccount?.id : accepted?.account?.id,
            expectedAccountId,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
