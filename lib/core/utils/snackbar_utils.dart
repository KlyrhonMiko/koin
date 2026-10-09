import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';

enum SnackBarType { success, error, info }

class KoinSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    late OverlayEntry overlayEntry;
    var dismissed = false;

    overlayEntry = OverlayEntry(
      builder: (context) => themes.wrap(
        _SnackBarWidget(
          message: message,
          subtitle: subtitle,
          type: type,
          onDismiss: () {
            if (dismissed) return;
            dismissed = true;
            overlayEntry.remove();
            overlayEntry.dispose();
          },
          duration: duration,
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  static void success(
    BuildContext context,
    String message, {
    String? subtitle,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: SnackBarType.success,
    );
  }

  static void error(BuildContext context, String message, {String? subtitle}) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: SnackBarType.error,
    );
  }

  static void info(BuildContext context, String message, {String? subtitle}) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: SnackBarType.info,
    );
  }
}

class _SnackBarWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final SnackBarType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _SnackBarWidget({
    required this.message,
    this.subtitle,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_SnackBarWidget> createState() => _SnackBarWidgetState();
}

class _SnackBarWidgetState extends State<_SnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    );
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(animation);
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(animation);
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (!_isDismissing) {
      _controller.forward();
    }
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    if (!_reduceMotion) {
      await _controller.reverse();
    }
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (accentColor, icon) = switch (widget.type) {
      SnackBarType.success => (
        AppTheme.incomeContentColor(context),
        Icons.check_rounded,
      ),
      SnackBarType.error => (
        AppTheme.errorColor(context),
        Icons.error_outline_rounded,
      ),
      SnackBarType.info => (
        AppTheme.primaryColor(context),
        Icons.info_outline_rounded,
      ),
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KoinSpacing.screenInset,
            12,
            KoinSpacing.screenInset,
            0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Dismissible(
                  key: ValueKey(this),
                  direction: DismissDirection.up,
                  resizeDuration: null,
                  onDismissed: (_) => widget.onDismiss(),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    onDismiss: _dismiss,
                    child: Material(
                      color: AppTheme.surfaceColor(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppTheme.dividerColor(context)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: accentColor, size: 21),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.message,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppTheme.textColor(context),
                                            height: 1.3,
                                          ),
                                    ),
                                    if (widget.subtitle?.isNotEmpty ??
                                        false) ...[
                                      const Gap(KoinSpacing.labelGap),
                                      Text(
                                        widget.subtitle!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textLightColor(
                                                context,
                                              ),
                                              height: 1.4,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
