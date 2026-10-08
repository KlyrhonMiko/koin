import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/services/quick_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = QuickTransactionService.channel;
  late QuickTransactionService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    service = QuickTransactionService();
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> sendNativeAction(String method) async {
    final handled = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
      (_) => handled.complete(),
    );
    await handled.future;
  }

  test('delivers a tile tap queued during cold startup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getLaunchAction');
      return 'addTransaction';
    });
    var opens = 0;
    await service.initialize(() => opens++);
    expect(opens, 1);
  });

  test('normal launch does not open a form; warm tile taps do', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    var opens = 0;
    await service.initialize(() => opens++);
    expect(opens, 0);
    await sendNativeAction('unrelated');
    expect(opens, 0);
    await sendNativeAction('addTransaction');
    expect(opens, 1);
    await sendNativeAction('addTransaction');
    expect(opens, 2);
  });

  test('does not navigate when startup response arrives after disposal', () async {
    final response = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (_) => response.future);
    var opens = 0;
    final initialization = service.initialize(() => opens++);
    service.dispose();
    response.complete('addTransaction');
    await initialization;
    expect(opens, 0);
  });

  test('missing native implementation does not break startup or setup', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    await service.initialize(() => fail('Must not open a transaction'));
    expect(await QuickTransactionService.addTile(), 'unavailable');
  });

  test('returns system setup results and handles platform failures', () async {
    for (final result in ['added', 'alreadyAdded', 'declined', 'unavailable']) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'addTile');
        return result;
      });
      expect(await QuickTransactionService.addTile(), result);
    }
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unsupported'),
    );
    expect(await QuickTransactionService.addTile(), 'unavailable');
  });

  test('other platforms do not call the Android bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Android bridge called on iOS'),
    );
    await service.initialize(() => fail('Must not open a transaction'));
    expect(await QuickTransactionService.addTile(), 'unavailable');
  });
}
