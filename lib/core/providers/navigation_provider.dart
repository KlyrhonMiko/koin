import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
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
