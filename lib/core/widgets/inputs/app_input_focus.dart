import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';

/// Shared focus behavior for every route, dialog, and sheet in an app window.
class AppInputFocus extends StatefulWidget {
  const AppInputFocus({super.key, required this.child});

  final Widget child;

  @override
  State<AppInputFocus> createState() => _AppInputFocusState();
}

class _AppInputFocusState extends State<AppInputFocus>
    with WidgetsBindingObserver {
  late FlutterView _view;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    _keyboardVisible = _view.viewInsets.bottom > 0;
  }

  @override
  void didChangeMetrics() {
    final visible = _view.viewInsets.bottom > 0;
    final closed = _keyboardVisible && !visible;
    _keyboardVisible = visible;
    if (!closed) return;

    final focus = FocusManager.instance.primaryFocus;
    // Keyboard dismissal should not clear focus from buttons or other controls.
    if (focus?.context?.findAncestorStateOfType<EditableTextState>() == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _view.viewInsets.bottom == 0 &&
          FocusManager.instance.primaryFocus == focus) {
        focus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: widget.child,
  );
}
