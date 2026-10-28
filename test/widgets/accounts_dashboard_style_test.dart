import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/cards/account_card_layout.dart';
import 'package:koin/core/widgets/cards/account_card_amount.dart';
import 'package:koin/core/widgets/inputs/app_input_focus.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/accounts/accounts_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final (width, scale, dark) in [
    (390.0, 1.0, true),
    (320.0, 1.8, false),
    (800.0, 1.0, false),
  ]) {
    testWidgets('account grid and forms fit $width at $scale text scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final fonts = FontLoader(KoinTypography.fontFamily);
        for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          fonts.addFont(
            rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'),
          );
        }
        await fonts.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
      final prefs = await SharedPreferences.getInstance();
      final accounts = [
        Account(
          id: 'cash',
          name: 'Cash',
          initialBalance: 250,
          iconCodePoint: KoinIcons.money.codePoint,
          colorHex: '#00D09E',
        ),
        for (final template in BankTemplate.templates.where(
          (t) => ['maribank', 'gcash', 'gotyme', 'maya'].contains(t.id),
        ))
          Account(
            id: template.id,
            name: template.id == 'maribank'
                ? 'MariBank Credit Account'
                : template.id == 'gotyme'
                ? 'GoTyme account for household purchases and monthly bills'
                : template.name,
            initialBalance: template.id == 'maya' ? 100000000 : 63,
            iconCodePoint: KoinIcons.bank.codePoint,
            colorHex: template.colorHex,
            logoAsset: template.logoAsset,
          ),
      ];
      final providers = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountAdapter(initial: accounts),
          ),
          savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
          dashboardStatsProvider.overrideWithValue(
            DashboardStats(
              totalIncome: 0,
              totalExpense: 0,
              currentBalance: 502,
              accounts: accounts,
              accountBalances: {
                for (final account in accounts)
                  account.id: account.initialBalance,
              },
              categorySpending: {},
            ),
          ),
        ],
      );
      addTearDown(providers.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: providers,
          child: MaterialApp(
            theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: AppInputFocus(
                child: RepaintBoundary(key: boundary, child: child!),
              ),
            ),
            home: const Scaffold(
              body: AccountsTab(
                animationSessionKey: 'style-test',
                showEntranceAnimations: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.text('Hold and drag to rearrange'), findsOneWidget);
      final cards = find.byType(AccountItem);
      final accountCardSize = tester.getSize(cards.first);
      final liveAmountWidth = tester
          .renderObject<RenderBox>(find.byType(AccountCardAmount).first)
          .constraints
          .maxWidth;
      final addTile = find.byTooltip('Add new account');
      expect(tester.getSize(addTile), accountCardSize);
      final addLabel = find.text('Add account');
      final addIcon = find.descendant(
        of: addTile,
        matching: find.byIcon(KoinIcons.plus),
      );
      expect(
        tester.getCenter(addIcon).dy,
        lessThan(tester.getTopLeft(addLabel).dy),
      );
      expect(tester.getCenter(addIcon).dx, tester.getCenter(addLabel).dx);
      expect(find.byTooltip('₱100,000,000.00'), findsOneWidget);
      if (width == 390) {
        expect(find.textContaining(RegExp(r'₱100(?:\.00)?M')), findsOneWidget);
      }
      final lastCardPosition = tester.getTopLeft(cards.last);
      final addPosition = tester.getTopLeft(addTile);
      if (scale == 1) {
        expect(addPosition.dy, lastCardPosition.dy);
        expect(addPosition.dx, greaterThan(lastCardPosition.dx));
      } else {
        expect(addPosition.dx, lastCardPosition.dx);
        expect(addPosition.dy, greaterThan(lastCardPosition.dy));
      }
      final first = tester.getTopLeft(cards.at(0));
      final second = tester.getTopLeft(cards.at(1));
      if (scale == 1) {
        expect(first.dy, second.dy);
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(first.dx, second.dx);
        expect(second.dy, greaterThan(first.dy));
      }
      final creditName = tester.renderObject<RenderParagraph>(
        find.text('MariBank Credit Account'),
      );
      expect(creditName.didExceedMaxLines, width == 390);
      if (scale == 1) expect(accountCardSize.height, lessThanOrEqualTo(105));
      for (final card in tester.widgetList<AccountItem>(cards)) {
        final finder = find.widgetWithText(AccountItem, card.account.name);
        expect(
          tester.getSize(finder).height,
          closeTo(accountCardSize.height, 1),
        );
      }
      final longName = tester.renderObject<RenderParagraph>(
        find.text('GoTyme account for household purchases and monthly bills'),
      );
      expect(longName.maxLines, 2);
      if (width == 390) expect(longName.didExceedMaxLines, isTrue);
      expect(tester.takeException(), isNull);
      final capture = Platform.environment['KOIN_CAPTURE_ACCOUNTS'];
      Future<void> snapshot(String name) async {
        if (capture != null && dark) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(capture).create(recursive: true);
            await File('$capture/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await snapshot('accounts');
      if (dark) {
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        await tester.tap(
          find.byTooltip('Hide balance and exclude from totals').first,
        );
        await tester.pumpAndSettle();
        expect(
          providers.read(accountProvider).value!.first.excludeFromTotal,
          isTrue,
        );
        expect(
          find.byTooltip('Show balance and include in totals'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Show balance and include in totals'));
        await tester.pumpAndSettle();
        expect(
          providers.read(accountProvider).value!.first.excludeFromTotal,
          isFalse,
        );
        expect(find.byType(AccountFormScreen), findsNothing);
        final source = tester.getCenter(
          find.byType(LongPressDraggable<String>).first,
        );
        final target = tester.getCenter(
          find.byType(LongPressDraggable<String>).at(1),
        );
        final drag = await tester.startGesture(source);
        await tester.pump(const Duration(milliseconds: 600));
        await drag.moveBy(const Offset(0, -12));
        await tester.pump();
        await drag.moveTo(target);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('account_drop_placeholder')),
          findsOneWidget,
        );
        expect(providers.read(accountProvider).value!.first.id, 'cash');
        await drag.up();
        await tester.pumpAndSettle();
        expect(providers.read(accountProvider).value![1].id, 'cash');
      }
      // Both forms show a live card preview with separate labeled fields.
      for (final editing in [true, false]) {
        final context = tester.element(find.byType(AccountsTab));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AccountFormScreen(account: editing ? accounts.first : null),
          ),
        );
        await tester.pumpAndSettle();
        await snapshot(editing ? 'edit-account' : 'create-account');
        final preview = find.byType(AccountCardLayout).first;
        expect(tester.getSize(preview).width, accountCardSize.width);
        if (scale == 1) {
          expect(
            tester.getSize(preview).height,
            closeTo(accountCardSize.height, 1),
          );
        }
        expect(
          find.descendant(of: preview, matching: find.byType(EditableText)),
          findsNothing,
        );
        final nameField = find.byKey(const ValueKey('account_name_field'));
        final balanceField = find.byKey(
          const ValueKey('account_balance_field'),
        );
        expect(find.text('Account name'), findsWidgets);
        expect(find.text('Balance'), findsOneWidget);
        const updatedName = 'Everyday account with a longer name';
        await tester.enterText(nameField, updatedName);
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(preview));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: nameField,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isFalse,
        );
        await tester.enterText(balanceField, '1234567.89');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: preview, matching: find.text(updatedName)),
          findsOneWidget,
        );
        final currency = providers.read(settingsProvider).currency;
        expect(
          tester.widget<TextField>(balanceField).controller!.text,
          '1,234,567.89',
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.byTooltip(currency.formatter.format(1234567.89)),
          ),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(nameField).maxLines, isNull);
        await tester.enterText(balanceField, '100000');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final previewAmountWidth = tester
            .renderObject<RenderBox>(
              find.descendant(
                of: preview,
                matching: find.byType(AccountCardAmount),
              ),
            )
            .constraints
            .maxWidth;
        // Live cards and previews both give the amount the full content width.
        expect(previewAmountWidth, liveAmountWidth);
        if (width == 390) {
          expect(
            find.descendant(of: preview, matching: find.text('₱100,000.00')),
            findsOneWidget,
          );
        }
        await tester.enterText(balanceField, '100000000');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(balanceField).controller!.text,
          '100,000,000',
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.byTooltip('₱100,000,000.00'),
          ),
          findsOneWidget,
        );
        if (width == 390) {
          expect(
            find.descendant(of: preview, matching: find.text('₱100M')),
            findsOneWidget,
          );
        }
        await snapshot(editing ? 'edit-large-balance' : 'create-large-balance');
        await tester.enterText(balanceField, '1234567.89');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final template = find.text(BankTemplate.templates.first.name).first;
        await tester.ensureVisible(template);
        await tester.tap(template);
        await tester.pumpAndSettle();
        final decorationSize = tester.getSize(preview);
        Finder decorationCard(String label) => find.descendant(
          of: find.widgetWithText(GestureDetector, label),
          matching: find.byType(AccountCardLayout),
        );
        await tester.ensureVisible(find.text('Card Decoration'));
        await tester.pumpAndSettle();
        final decorationScroll = tester
            .widget<ListView>(
              find.ancestor(
                of: decorationCard('Auto'),
                matching: find.byType(ListView),
              ),
            )
            .controller!;
        expect(find.text('Swipe to browse'), findsOneWidget);
        await tester.ensureVisible(decorationCard('Auto'));
        await tester.pumpAndSettle();
        await tester.drag(
          decorationCard('Auto'),
          Offset(-decorationSize.width, 0),
        );
        await tester.pumpAndSettle();
        expect(decorationScroll.offset, greaterThan(0));
        for (final (label, shape) in [
          ('Auto', null),
          ('Style 1', 0),
          ('Style 8', 7),
          ('Auto', null),
        ]) {
          decorationScroll.jumpTo(
            ((shape == null ? 0 : shape + 1) *
                    (decorationSize.width + KoinSpacing.cardGap))
                .clamp(0.0, decorationScroll.position.maxScrollExtent),
          );
          await tester.pumpAndSettle();
          final card = decorationCard(label);
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          expect(tester.getSize(card), decorationSize);
          expect(
            find.descendant(of: card, matching: find.text(updatedName)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.byTooltip('₱1,234,567.89'),
            ),
            findsOneWidget,
          );
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(
            tester.widget<AccountCardLayout>(preview).account.cardShapeType,
            shape,
          );
        }
        await snapshot(
          editing ? 'edit-card-decoration' : 'create-card-decoration',
        );
        final feeField = find.byKey(
          const ValueKey('account_transfer_fee_field'),
        );
        await tester.ensureVisible(feeField);
        await tester.pumpAndSettle();
        await tester.enterText(feeField, '2.5');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Percentage'));
        await tester.tap(find.text('Percentage'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(feeField).decoration!.suffixText, '%');
        expect(tester.widget<TextField>(feeField).controller!.text, '2.5');
        await tester.ensureVisible(find.text('Fixed amount'));
        await tester.tap(find.text('Fixed amount'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(feeField).decoration!.prefixText,
          '${currency.symbol} ',
        );
        expect(tester.widget<TextField>(feeField).controller!.text, '2.5');
        await tester.ensureVisible(feeField);
        await tester.pumpAndSettle();
        await snapshot(
          editing ? 'edit-account-settings' : 'create-account-settings',
        );
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(AccountFormScreen))).pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
