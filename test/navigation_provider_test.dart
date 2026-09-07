import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/providers/navigation_provider.dart';

void main() {
  group('NavigationNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is 0 and cannot pop', () {
      final index = container.read(navigationProvider);
      final notifier = container.read(navigationProvider.notifier);

      expect(index, 0);
      expect(notifier.canPop(), false);
      expect(notifier.pop(), false);
      expect(container.read(navigationProvider), 0);
    });

    test('navigating to tab updates state and canPop becomes true', () {
      final notifier = container.read(navigationProvider.notifier);

      notifier.setIndex(1);
      expect(container.read(navigationProvider), 1);
      expect(notifier.canPop(), true);

      notifier.setIndex(2);
      expect(container.read(navigationProvider), 2);
      expect(notifier.canPop(), true);
    });

    test('pop navigates back through history stack', () {
      final notifier = container.read(navigationProvider.notifier);

      // Home (0) -> Activity (1) -> Budgets (2)
      notifier.setIndex(1);
      notifier.setIndex(2);

      // Pop should go back to Activity (1)
      final poppedFirst = notifier.pop();
      expect(poppedFirst, true);
      expect(container.read(navigationProvider), 1);
      expect(notifier.canPop(), true);

      // Pop again should go back to Home (0)
      final poppedSecond = notifier.pop();
      expect(poppedSecond, true);
      expect(container.read(navigationProvider), 0);
      expect(notifier.canPop(), false);

      // Pop at root should return false
      final poppedAtRoot = notifier.pop();
      expect(poppedAtRoot, false);
      expect(container.read(navigationProvider), 0);
    });

    test('returning directly to Home resets the history stack', () {
      final notifier = container.read(navigationProvider.notifier);

      notifier.setIndex(2);
      notifier.setIndex(3);
      expect(notifier.canPop(), true);

      // User taps Home tab directly
      notifier.setIndex(0);
      expect(container.read(navigationProvider), 0);
      expect(notifier.canPop(), false);
      expect(notifier.pop(), false);
    });

    test('revisiting a tab removes duplicate from earlier in history', () {
      final notifier = container.read(navigationProvider.notifier);

      // 0 -> 1 -> 2 -> 1
      notifier.setIndex(1);
      notifier.setIndex(2);
      notifier.setIndex(1);

      // Back should go to 2
      expect(notifier.pop(), true);
      expect(container.read(navigationProvider), 2);

      // Back should go to 0
      expect(notifier.pop(), true);
      expect(container.read(navigationProvider), 0);

      // At root
      expect(notifier.canPop(), false);
    });
  });
}
