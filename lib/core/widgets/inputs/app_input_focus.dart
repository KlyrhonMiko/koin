import 'dart:async';
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
  Timer? _keyboardDismissal;

  void _cancelKeyboardDismissal() {
    _keyboardDismissal?.cancel();
    _keyboardDismissal = null;
  }

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
    if (visible) {
      _cancelKeyboardDismissal();
      return;
    }
    if (!closed && _keyboardDismissal == null) return;

    _cancelKeyboardDismissal();

    final focus = FocusManager.instance.primaryFocus;
    // Keyboard dismissal should not clear focus from buttons or other controls.
    if (focus?.context?.findAncestorStateOfType<EditableTextState>() == null) {
      return;
    }
    // Android IME transitions can briefly report zero insets while opening or
    // changing keyboards. Wait for a stable dismissal before clearing focus;
    // otherwise unfocusing here closes the keyboard we just asked to open.
    _keyboardDismissal = Timer(const Duration(milliseconds: 200), () {
      _keyboardDismissal = null;
      if (mounted &&
          _view.viewInsets.bottom == 0 &&
          FocusManager.instance.primaryFocus == focus) {
        focus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _cancelKeyboardDismissal();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    // A new tap starts a fresh interaction, including reopening the same field
    // before Android has reported the new keyboard insets.
    onPointerDown: (_) => _cancelKeyboardDismissal(),
    child: Actions(
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
    ),
  );
}
