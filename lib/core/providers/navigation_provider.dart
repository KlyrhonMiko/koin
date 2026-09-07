import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  final List<int> _history = [0];

  @override
  int build() {
    _history.clear();
    _history.add(0);
    return 0;
  }

  void setIndex(int index) {
    if (state == index) return;

    if (index == 0) {
      // Returning to Home/Dashboard resets the stack
      _history.clear();
      _history.add(0);
    } else {
      _history.remove(index);
      _history.add(index);
    }
    state = index;
  }

  bool canPop() {
    return _history.length > 1 || state != 0;
  }

  bool pop() {
    if (_history.length > 1) {
      _history.removeLast();
      state = _history.last;
      return true;
    } else if (state != 0) {
      _history.clear();
      _history.add(0);
      state = 0;
      return true;
    }
    return false;
  }
}

final navigationProvider = NotifierProvider<NavigationNotifier, int>(() {
  return NavigationNotifier();
});

final pageControllerProvider = Provider<PageController>((ref) {
  final controller = PageController(initialPage: 0);
  ref.onDispose(() => controller.dispose());
  return controller;
});

class ActivityTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final activityTabProvider = NotifierProvider<ActivityTabNotifier, int>(() {
  return ActivityTabNotifier();
});

class PortfolioTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final portfolioTabProvider = NotifierProvider<PortfolioTabNotifier, int>(() {
  return PortfolioTabNotifier();
});
