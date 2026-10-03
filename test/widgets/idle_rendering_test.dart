import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/widgets/voice_input_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeVoiceNotifier extends VoiceInputNotifier {
  @override
  Future<void> startListening() async {
    state = state.copyWith(isAvailable: true, isListening: true);
  }

  @override
  Future<void> stopListening() async {
    state = state.copyWith(isListening: false);
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ledgerProvider.overrideWithValue(
        InMemoryLedgerAdapter(
          initial: [
            AppTransaction(
              id: 'coffee',
              note: 'Coffee',
              amount: 25,
              date: DateTime.now(),
              type: TransactionType.expense,
              categoryId: 'food',
              accountId: 'cash',
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
              iconCodePoint: Icons.payments.codePoint,
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
              iconCodePoint: Icons.restaurant.codePoint,
              colorHex: '#008080',
              type: TransactionType.expense,
              budget: 10,
            ),
          ],
        ),
      ),
      categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
      voiceInputProvider.overrideWith(FakeVoiceNotifier.new),
    ],
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer providers,
    Widget screen, {
    bool dark = false,
    double width = 420,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, dark),
          home: screen,
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'main layout with an overspent budget stops rendering when idle (dark=$dark)',
      (tester) async {
        final providers = container();
        addTearDown(providers.dispose);
        providers.read(navigationProvider.notifier).setIndex(2);
        await pumpScreen(tester, providers, const MainLayout(), dark: dark);
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets('transaction form decorative animations settle', (tester) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(tester, providers, const AddTransactionScreen(), width: 480);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('voice animations stop when listening ends', (tester) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const Scaffold(body: VoiceInputSheet()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(providers.read(voiceInputProvider).isListening, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await providers.read(voiceInputProvider.notifier).stopListening();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
