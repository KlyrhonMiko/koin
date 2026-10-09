import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedSuggester extends TestStubSuggesterAdapter {
  Completer<CategorySuggestion?>? pending;
  @override
  Future<CategorySuggestion?> suggest(SuggestionContext context) =>
      pending?.future ?? super.suggest(context);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late DelayedSuggester suggester;
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('KoinTest')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'analysis_filter_index': 1});
    final prefs = await SharedPreferences.getInstance();
    suggester = DelayedSuggester();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categorySuggesterProvider.overrideWithValue(suggester),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'expense',
                amount: 20,
                date: DateTime.now(),
                accountId: 'cash',
                categoryId: 'food',
                type: TransactionType.expense,
              ),
            ],
          ),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                initialBalance: 5000,
                iconCodePoint: Icons.payments.codePoint,
                colorHex: '#008080',
              ),
              Account(
                id: 'bank',
                name: 'Bank',
                initialBalance: 2000,
                iconCodePoint: Icons.account_balance.codePoint,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'food',
                name: 'Food',
                type: TransactionType.expense,
                iconCodePoint: Icons.restaurant.codePoint,
                colorHex: '#008080',
              ),
              TransactionCategory(
                id: 'transport',
                name: 'Transport',
                type: TransactionType.expense,
                iconCodePoint: Icons.directions_bus.codePoint,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        forecastProvider(1).overrideWith(
          (ref) async => ForecastData(
            forecastedInflow: 1000,
            forecastedOutflow: 500,
            currentBaseline: 100,
            predictedNetBalance: 600,
            isWarning: true,
            firstShortfallDate: DateTime(2026, 10, 12),
            lowerNetBalance: 300,
            upperNetBalance: 900,
            historyMonths: 12,
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> launch(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'KoinTest',
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: boundaryKey, child: child!),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder noteField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'Add a note...',
  );

  SelectionTile categoryTile(WidgetTester tester) =>
      tester.widget<SelectionTile>(
        find.byWidgetPredicate(
          (widget) => widget is SelectionTile && widget.label == 'Category',
        ),
      );

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['KOIN_CAPTURE_ANALYTICS'] != '1') return;
    await tester.pump();
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/analytics-review').create(recursive: true);
      await File(
        'build/analytics-review/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
  }

  testWidgets('weak evidence requires accepting the suggested category', (
    tester,
  ) async {
    suggester.stubbedSuggestion = const CategorySuggestion(
      categoryId: 'food',
      originAccountId: 'bank',
      type: TransactionType.expense,
      confidence: 0.33,
      canAutoApply: false,
    );
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'burger');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, isNull);
    final useSuggestion = find.text('Use suggested category: Food');
    expect(useSuggestion, findsOneWidget);
    await capture(tester, 'category-suggestion');
    await tester.ensureVisible(useSuggestion);
    await tester.tap(useSuggestion);
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Food');
    suggester.stubbedSuggestion = const CategorySuggestion(
      categoryId: 'transport',
      type: TransactionType.expense,
      confidence: 0.95,
    );
    await tester.enterText(noteField(), 'bus ticket');
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Food');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'strong category suggestion preserves account and transaction type',
    (tester) async {
      await launch(tester, const AddTransactionScreen());
      await tester.ensureVisible(find.text('Select account'));
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      suggester.stubbedSuggestion = const CategorySuggestion(
        categoryId: 'food',
        originAccountId: 'bank',
        type: TransactionType.expense,
        confidence: 0.95,
      );
      await tester.enterText(noteField(), 'lunch');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(categoryTile(tester).selectedName, 'Food');
      expect(find.textContaining('Cash •'), findsOneWidget);
      suggester.stubbedSuggestion = const CategorySuggestion(
        type: TransactionType.transfer,
        originAccountId: 'bank',
        destinationAccountId: 'cash',
        confidence: 0.95,
      );
      await tester.enterText(noteField(), 'deposit');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Category'), findsOneWidget);
      expect(find.textContaining('Cash •'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clearing the note discards an in-flight suggestion', (
    tester,
  ) async {
    suggester.pending = Completer<CategorySuggestion?>();
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'coffee');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(noteField(), '');
    suggester.pending!.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, isNull);
  });

  testWidgets('manual picker choice wins over an in-flight suggestion', (
    tester,
  ) async {
    suggester.pending = Completer<CategorySuggestion?>();
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'coffee');
    await tester.pump(const Duration(milliseconds: 600));
    final category = find.byWidgetPredicate(
      (widget) => widget is SelectionTile && widget.label == 'Category',
    );
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    suggester.pending!.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Transport');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('forecast keeps details optional at text scale $scale', (
      tester,
    ) async {
      await launch(tester, const AnalysisScreen(), scale: scale);
      expect(find.text('Review payments before Oct 12.'), findsOneWidget);
      expect(find.text('Possible balance range'), findsNothing);
      expect(find.text('Expected income'), findsNothing);
      expect(find.text(r'$600.00'), findsOneWidget);
      await capture(tester, 'forecast-scale-$scale');
      await tester.ensureVisible(find.text('Forecast details'));
      await tester.tap(find.text('Forecast details'));
      await tester.pumpAndSettle();
      expect(find.text('Possible balance range'), findsOneWidget);
      expect(find.text('Expected income'), findsOneWidget);
      await tester.ensureVisible(find.text('Possible balance range'));
      if (scale == 1) await capture(tester, 'forecast-details');
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Possible balance range'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
