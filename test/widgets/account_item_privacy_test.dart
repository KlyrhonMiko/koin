import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/widgets/account_item.dart';
import 'package:koin/core/utils/animation_utils.dart';
import 'package:koin/core/theme.dart';

void main() {
  setUp(() {
    AnimationTracker.clear();
  });

  testWidgets('AccountItem resets AnimationTracker with 0.0 when private', (
    tester,
  ) async {
    final account = Account(
      id: 'acc_1',
      name: 'Test Account',
      iconCodePoint: 0xe000,
      colorHex: '#2196F3',
      excludeFromTotal: true,
    );

    const sessionKey = 'session_1';
    const token = 'acc_bal_acc_1_session_1';

    // Manually set a value to ensure we are actually resetting it
    AnimationTracker.updateValue(token, 1000.0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Colors.blue, false),
        home: Scaffold(
          body: AccountItem(
            account: account,
            balance: 1000.0,
            currencySymbol: r'$',
            animationSessionKey: sessionKey,
            onTap: () {},
          ),
        ),
      ),
    );

    // After build, the tracker should have been reset to 0.0 by AccountItem
    expect(AnimationTracker.getValue(token), 0.0);
  });
}
