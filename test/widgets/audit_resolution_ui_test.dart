import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/app_startup.dart';
import 'package:koin/core/maintenance/external_backup.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/onboarding/account_setup_screen.dart';
import 'package:koin/features/settings/backup_password_sheet.dart';
import 'package:koin/features/settings/settings_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/widgets/filter_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:koin/features/settings/voice_language_sheet.dart';

class _AvailableSpeech extends VoiceInputNotifier {
  @override
  Future<List<LocaleName>> availableLocales() async => [
    LocaleName('fr_FR', 'French'),
  ];
}

class _WaitingAccounts extends AccountNotifier {
  _WaitingAccounts(this.accounts);
  final Future<List<Account>> accounts;

  @override
  Future<List<Account>> build() => accounts;
}

class _IdleRecovery implements RecoveryService {
  @override
  final status = ValueNotifier(const RecoveryStatus());
  @override
  final external = ExternalBackup();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer c;
  late SharedPreferences prefs;

  setUpAll(() async {
    final outfit = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    for (final entry in {
      'PhosphorRegular': 'Phosphor.ttf',
      'PhosphorFill': 'Phosphor-Fill.ttf',
      'PhosphorBold': 'Phosphor-Bold.ttf',
    }.entries) {
      await (FontLoader('packages/phosphor_icons/${entry.key}')..addFont(
            rootBundle.load('packages/phosphor_icons/lib/fonts/${entry.value}'),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'currency_code': 'PHP',
      'setup_completed': false,
    });
    prefs = await SharedPreferences.getInstance();
    final recovery = _IdleRecovery();
    addTearDown(recovery.status.dispose);
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recoveryServiceProvider.overrideWithValue(recovery),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                initialBalance: 0,
                iconCodePoint: KoinIcons.money.codePoint,
                colorHex: '#00D09E',
              ),
            ],
          ),
        ),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(),
        ),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
        voiceInputProvider.overrideWith(_AvailableSpeech.new),
      ],
    );
    addTearDown(c.dispose);
    await c.read(accountProvider.future);
    await c.read(transactionProvider.future);
    await c.read(categoriesProvider.future);
  });

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
    double scale = 1,
    double width = 390,
    double height = 844,
    double keyboardInset = 0,
    Color? accent,
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container ?? c,
        child: MaterialApp(
          theme: AppTheme.getTheme(accent ?? const Color(0xff00d09e), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: RepaintBoundary(
              key: const ValueKey('audit-preview'),
              child: child!,
            ),
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('AUDIT_FIX_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('audit-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/audit-fix-previews').create(recursive: true);
      await File('build/audit-fix-previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  testWidgets(
    'type filters expose selected state, readable text and 48dp targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, const Scaffold(body: FilterBottomSheet()));
      final node = tester.getSemantics(find.text('All'));
      expect(node.flagsCollection.isButton, true);
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      final chip = find
          .ancestor(of: find.text('All'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      final text = tester.widget<Text>(find.text('All'));
      expect(
        AppTheme.contrast(text.style!.color!, const Color(0xff00d09e)),
        greaterThanOrEqualTo(4.5),
      );
      await capture(tester, 'filters-light');
      semantics.dispose();
    },
  );

  testWidgets('black accent keeps add transaction visible', (tester) async {
    await open(
      tester,
      const MainLayout(),
      dark: true,
      accent: const Color(0xff171717),
    );
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect((fab.child as Icon).color, isNull);
    expect(
      AppTheme.contrast(fab.backgroundColor!, fab.foregroundColor!),
      greaterThanOrEqualTo(3),
    );
    final context = tester.element(find.byType(MainLayout));
    final theme = Theme.of(context);
    final textActionColor = theme.textButtonTheme.style!.foregroundColor!
        .resolve({})!;
    expect(
      AppTheme.contrast(textActionColor, AppTheme.surfaceLightColor(context)),
      greaterThanOrEqualTo(4.5),
    );
    final activeNavIcon = tester.widget<Icon>(find.byIcon(KoinIcons.houseFill));
    expect(
      AppTheme.contrast(
        activeNavIcon.color!,
        AppTheme.surfaceLightColor(context),
      ),
      greaterThanOrEqualTo(3),
    );
    await capture(tester, 'black-accent-navigation');
  });

  testWidgets('theme swatches have names, selected state and 48dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, const SettingsScreen());
    final swatch = find.bySemanticsLabel('Teal theme');
    expect(swatch, findsOneWidget);
    expect(tester.getSize(swatch).width, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(swatch).flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    await capture(tester, 'settings-light');
    semantics.dispose();
  });

  testWidgets('voice shortcut is named and large enough to tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, const AddTransactionScreen());
    final voice = find.bySemanticsLabel('Add transaction with voice');
    expect(voice, findsOneWidget);
    expect(tester.getSize(voice).shortestSide, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  testWidgets('fresh onboarding defaults to Philippine peso', (tester) async {
    await prefs.remove('currency_code');
    c.invalidate(settingsProvider);
    await open(tester, const AccountSetupScreen());
    expect(c.read(settingsProvider).currency.code, 'PHP');
    expect(find.text('PHP · Philippine Peso'), findsOneWidget);
    expect(find.text('CNY · Chinese Yuan'), findsNothing);
    expect(SettingsSnapshot.capture(prefs)['currency_code'], 'PHP');
    await capture(tester, 'setup-default-php');
  });

  testWidgets('onboarding keeps the startup brand while accounts load', (
    tester,
  ) async {
    final pending = Completer<List<Account>>();
    final waiting = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountProvider.overrideWith(() => _WaitingAccounts(pending.future)),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
      ],
    );
    addTearDown(waiting.dispose);
    await open(tester, const AccountSetupScreen(), container: waiting);
    expect(find.byType(KoinStartupPlaceholder), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await capture(tester, 'setup-startup');
    pending.complete(c.read(accountProvider).requireValue);
    await tester.pumpAndSettle();
    expect(find.text('Start with your balance'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('PHP · Philippine Peso'), findsOneWidget);
  });

  testWidgets(
    'setup validates and saves one balance without inventing income',
    (tester) async {
      await open(tester, const AccountSetupScreen());
      await capture(tester, 'setup-light');
      await tester.enterText(find.byKey(const ValueKey('setup-balance')), '');
      await tester.ensureVisible(find.text('Start tracking'));
      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(prefs.getBool('setup_completed'), false);
      await tester.enterText(
        find.byKey(const ValueKey('setup-name')),
        'Everyday cash',
      );
      await tester.enterText(
        find.byKey(const ValueKey('setup-balance')),
        '1200.50',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start tracking'));
      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(prefs.getBool('setup_completed'), true);
      final account = c.read(accountProvider).requireValue.single;
      expect(account.name, 'Everyday cash');
      expect(account.initialBalance, 1200.5);
      expect(c.read(transactionProvider).requireValue, isEmpty);
    },
  );

  testWidgets('large text setup can be skipped without changing records', (
    tester,
  ) async {
    await open(
      tester,
      const AccountSetupScreen(),
      dark: true,
      scale: 2,
      width: 320,
    );
    await capture(tester, 'setup-large-dark');
    await tester.scrollUntilVisible(
      find.text('Start tracking'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'setup-large-dark-controls');
    await tester.scrollUntilVisible(
      find.text('Skip for now'),
      -350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('setup_completed'), true);
    expect(c.read(accountProvider).requireValue.single.initialBalance, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup keeps its draft through keyboard and layout changes', (
    tester,
  ) async {
    await open(tester, const AccountSetupScreen(), dark: true);
    await capture(tester, 'setup-dark');
    await tester.enterText(
      find.byKey(const ValueKey('setup-name')),
      'Everyday money',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup-balance')),
      '1200.50',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    for (final size in [
      (name: 'setup-keyboard', width: 320.0, height: 640.0, inset: 280.0),
      (name: 'setup-landscape', width: 844.0, height: 390.0, inset: 0.0),
      (name: 'setup-tablet', width: 900.0, height: 1200.0, inset: 0.0),
    ]) {
      await open(
        tester,
        const AccountSetupScreen(),
        dark: true,
        width: size.width,
        height: size.height,
        keyboardInset: size.inset,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('setup-balance')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('setup-name')))
            .controller!
            .text,
        'Everyday money',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('setup-balance')))
            .controller!
            .text,
        '1,200.50',
      );
      await capture(tester, size.name);
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Start tracking'));
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('setup_completed'), true);
    expect(c.read(accountProvider).requireValue.single.initialBalance, 1200.5);
  });

  testWidgets(
    'backup protection validates confirmation and allows explicit plain export',
    (tester) async {
      BackupPasswordResult? result;
      await open(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await BackupPasswordSheet.show(context),
              child: const Text('Export'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await capture(tester, 'backup-password-light');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 8 characters'), findsNWidgets(2));
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'example password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'different',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.password, isNull);
    },
  );

  testWidgets('same-day scheduled balance activates at its timestamp', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 23, 13);
    final clock = ProviderContainer(
      overrides: [
        calendarClockProvider.overrideWithValue(() => now),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                initialBalance: 100,
                iconCodePoint: 0,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'future',
                amount: 50,
                date: DateTime(2026, 10, 23, 14),
                type: TransactionType.income,
                accountId: 'cash',
                categoryId: 'salary',
              ),
            ],
          ),
        ),
      ],
    );
    final sub = clock.listen(dashboardStatsProvider, (_, _) {});
    await clock.read(accountProvider.future);
    await clock.read(transactionProvider.future);
    expect(clock.read(dashboardStatsProvider).currentBalance, 100);
    now = DateTime(2026, 10, 23, 14);
    await tester.pump(const Duration(hours: 1));
    expect(clock.read(dashboardStatsProvider).currentBalance, 150);
    sub.close();
    clock.dispose();
  });

  test('speech language defaults to system and survives snapshots', () async {
    expect(c.read(settingsProvider).voiceLocale, isNull);
    await c.read(settingsProvider.notifier).setVoiceLocale('fr_FR');
    final snapshot = SettingsSnapshot.capture(prefs);
    await c.read(settingsProvider.notifier).setVoiceLocale(null);
    await SettingsSnapshot.restore(prefs, snapshot);
    c.invalidate(settingsProvider);
    expect(c.read(settingsProvider).voiceLocale, 'fr_FR');
    await SettingsSnapshot.restore(prefs, {});
    c.invalidate(settingsProvider);
    expect(c.read(settingsProvider).voiceLocale, isNull);
    expect(c.read(settingsProvider).setupCompleted, true);
  });

  testWidgets('speech language picker saves a readable name', (tester) async {
    await open(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => VoiceLanguageSheet.show(context),
            child: const Text('Languages'),
          ),
        ),
      ),
      dark: true,
      scale: 2,
      width: 320,
    );
    await tester.tap(find.text('Languages'));
    await tester.pumpAndSettle();
    await capture(tester, 'voice-language-large-dark');
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).voiceLocale, 'fr_FR');
    expect(c.read(settingsProvider).voiceLocaleName, 'French');
    expect(tester.takeException(), isNull);
  });
}
