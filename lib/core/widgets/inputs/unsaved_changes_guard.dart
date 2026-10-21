import 'package:koin/core/icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../sheets/confirmation_sheet.dart';

/// Keeps an editor's opening draft until the user saves or confirms discarding it.
/// Drafts should use value equality (for example, records of immutable values).
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.draft,
    required this.child,
    this.listenables = const [],
    this.isSaving,
    this.canLeave,
    this.title = 'Discard changes?',
  });

  final Object Function() draft;
  final Widget child;
  final List<Listenable> listenables;
  final bool Function()? isSaving;
  final bool Function()? canLeave;
  final String title;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  late final Object _openingDraft;
  bool _discarded = false;
  bool _promptOpen = false;
  ModalRoute<dynamic>? _route;

  bool get _blocksExit =>
      !_discarded &&
      !(widget.canLeave?.call() ?? false) &&
      ((widget.isSaving?.call() ?? false) || widget.draft() != _openingDraft);

  @override
  void initState() {
    super.initState();
    _openingDraft = widget.draft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final route = _route;
    if (route is _EditorSheetRoute<dynamic>) route.guard = this;
  }

  void _requestDiscard() {
    if (!mounted || _promptOpen || (widget.isSaving?.call() ?? false)) return;
    _promptOpen = true;
    // A sheet drag can call this while Navigator.pop holds its navigation lock.
    scheduleMicrotask(_confirmDiscard);
  }

  Future<void> _confirmDiscard() async {
    if (!mounted) return;
    final discard = await ConfirmationSheet.show(
      context: context,
      title: widget.title,
      description: 'Your unsaved changes will be lost.',
      confirmLabel: 'Discard',
      isDanger: true,
      confirmColor: AppTheme.errorColor(context),
      icon: KoinIcons.trash,
    );
    _promptOpen = false;
    if (!mounted || discard != true || (widget.isSaving?.call() ?? false)) {
      return;
    }
    setState(() => _discarded = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && (_route?.isCurrent ?? false)) Navigator.pop(context);
  }

  @override
  void dispose() {
    final route = _route;
    if (route is _EditorSheetRoute<dynamic> && identical(route.guard, this)) {
      route.guard = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(widget.listenables),
    builder: (context, _) => PopScope<Object?>(
      canPop: !_blocksExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestDiscard();
      },
      child: widget.child,
    ),
  );
}

/// Also intercepts drag dismissal, which uses Navigator.pop rather than maybePop.
/// The sheet's guard must allow leaving after a successful save.
Future<T?> showEditorBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor = Colors.transparent,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push<T>(
    _EditorSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
    ),
  );
}

class _EditorSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _EditorSheetRoute({
    required super.builder,
    required super.capturedThemes,
    required super.isScrollControlled,
    required super.backgroundColor,
    required super.modalBarrierColor,
    required super.barrierLabel,
    required super.barrierOnTapHint,
  });

  _UnsavedChangesGuardState? guard;

  @override
  bool didPop(T? result) {
    final currentGuard = guard;
    if (currentGuard != null && currentGuard._blocksExit) {
      controller?.forward();
      currentGuard._requestDiscard();
      return false;
    }
    return super.didPop(result);
  }
}
