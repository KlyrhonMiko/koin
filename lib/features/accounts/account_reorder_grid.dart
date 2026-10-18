import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';

/// A stable set of drop slots: cards preview the order without moving the
/// hit targets underneath the pointer or writing to storage on every hover.
class AccountReorderGrid extends StatefulWidget {
  const AccountReorderGrid({
    super.key,
    required this.items,
    required this.columns,
    required this.cardWidth,
    required this.cardHeight,
    required this.addButton,
    required this.onReorder,
  });

  final List<({String id, Widget child})> items;
  final int columns;
  final double cardWidth;
  final double cardHeight;
  final Widget addButton;
  final void Function(String id, int index) onReorder;

  @override
  State<AccountReorderGrid> createState() => _AccountReorderGridState();
}

class _AccountReorderGridState extends State<AccountReorderGrid>
    with SingleTickerProviderStateMixin {
  final _gridKey = GlobalKey();
  late final AnimationController _landing;
  EdgeDraggingAutoScroller? _autoScroller;
  OverlayEntry? _landingOverlay;
  List<String>? _preview;
  String? _draggedId;
  bool _accepted = false;
  bool _settling = false;
  Offset? _pointer;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  List<String> get _ids => widget.items.map((item) => item.id).toList();
  Offset _slot(int index) => Offset(
    (index % widget.columns) * (widget.cardWidth + KoinSpacing.cardGap),
    (index ~/ widget.columns) * (widget.cardHeight + KoinSpacing.cardGap),
  );

  @override
  void initState() {
    super.initState();
    _landing = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autoScroller?.stopAutoScroll();
    _autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      velocityScalar: 50,
      onScrollViewScrolled: () {
        if (mounted && _pointer != null) _previewAt(_pointer!);
      },
    );
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _landingOverlay?.remove();
    _landingOverlay?.dispose();
    _landing.dispose();
    super.dispose();
  }

  void _start(String id) {
    HapticService.medium();
    setState(() {
      _draggedId = id;
      _preview = _ids;
      _accepted = false;
    });
  }

  void _previewAt(Offset globalPosition) {
    if (_draggedId == null || _settling) return;
    final box = _gridKey.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(globalPosition);
    if (!(Offset.zero & box.size).contains(local)) {
      if (_preview!.indexOf(_draggedId!) != _ids.indexOf(_draggedId!)) {
        setState(() => _preview = _ids);
      }
      return;
    }
    final column = (local.dx / (widget.cardWidth + KoinSpacing.cardGap))
        .floor()
        .clamp(0, widget.columns - 1);
    final row = (local.dy / (widget.cardHeight + KoinSpacing.cardGap))
        .floor()
        .clamp(0, (widget.items.length - 1) ~/ widget.columns);
    final index = (row * widget.columns + column).clamp(
      0,
      widget.items.length - 1,
    );
    if (_preview!.indexOf(_draggedId!) == index) return;
    HapticService.selection();
    setState(() {
      _preview!.remove(_draggedId);
      _preview!.insert(index, _draggedId!);
    });
  }

  void _clear() {
    _landingOverlay?.remove();
    _landingOverlay?.dispose();
    _landingOverlay = null;
    if (!mounted) return;
    setState(() {
      _pointer = null;
      _draggedId = null;
      _preview = null;
      _settling = false;
    });
  }

  Future<void> _finish(DraggableDetails details, Widget child) async {
    _autoScroller?.stopAutoScroll();
    if (!mounted || _draggedId == null) return;
    // Rejected drops visibly return to the original slot.
    if (!_accepted) setState(() => _preview = _ids);
    final index = _preview!.indexOf(_draggedId!);
    if (index < 0 || MediaQuery.disableAnimationsOf(context)) {
      _clear();
      return;
    }
    setState(() => _settling = true);
    final box = _gridKey.currentContext!.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final start = overlayBox.globalToLocal(details.offset);
    final end = overlayBox.globalToLocal(box.localToGlobal(_slot(index)));
    _landingOverlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _landing,
        builder: (context, _) {
          final t = _curve.transform(_landing.value);
          final position = Offset.lerp(start, end, t)!;
          return Positioned(
            left: 0,
            top: 0,
            width: widget.cardWidth,
            height: widget.cardHeight,
            child: IgnorePointer(
              child: Transform.translate(
                offset: position,
                child: Transform.scale(
                  scale: lerpDouble(1.03, 1, t),
                  child: Material(
                    color: Colors.transparent,
                    elevation: lerpDouble(12, 0, t)!,
                    borderRadius: BorderRadius.circular(KoinShape.field),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(_landingOverlay!);
    await _landing
        .forward(from: 0)
        .orCancel
        .then<void>((_) => _clear(), onError: (Object _) {});
  }

  Widget _placeholder(BuildContext context) => Semantics(
    label: 'Drop account here',
    child: Container(
      key: const ValueKey('account_drop_placeholder'),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KoinShape.field),
        border: Border.all(color: AppTheme.primaryColor(context), width: 2),
      ),
      child: Icon(
        Icons.drag_indicator_rounded,
        color: AppTheme.primaryColor(context),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final order = _preview ?? _ids;
    final duration = KoinMotion.duration(context, _duration);
    final rows =
        (widget.items.length + 1 + widget.columns - 1) ~/ widget.columns;
    return DragTarget<String>(
      // Flutter hit-tests the initial drag before calling onDragStarted.
      onWillAcceptWithDetails: (details) => _ids.contains(details.data),
      onLeave: (_) {
        if (_draggedId != null && !_settling) {
          setState(() => _preview = _ids);
        }
      },
      onAcceptWithDetails: (details) {
        _accepted = true;
        widget.onReorder(details.data, _preview!.indexOf(details.data));
      },
      builder: (context, candidates, rejected) => SizedBox(
        key: _gridKey,
        height: rows * widget.cardHeight + (rows - 1) * KoinSpacing.cardGap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final item in widget.items)
              AnimatedPositioned(
                key: ValueKey('account_slot_${item.id}'),
                duration: duration,
                curve: _curve,
                left: _slot(order.indexOf(item.id)).dx,
                top: _slot(order.indexOf(item.id)).dy,
                // Content changes (such as a savings footer) need their full
                // size immediately; only the reorder position interpolates.
                child: SizedBox(
                  width: widget.cardWidth,
                  height: widget.cardHeight,
                  child: LongPressDraggable<String>(
                    data: item.id,
                    maxSimultaneousDrags: _draggedId == null ? 1 : 0,
                    hapticFeedbackOnStart: false,
                    onDragStarted: () => _start(item.id),
                    onDragUpdate: (details) {
                      _pointer = details.globalPosition;
                      _autoScroller!.startAutoScrollIfNecessary(
                        Rect.fromCenter(
                          center: details.globalPosition,
                          width: 48,
                          height: 48,
                        ),
                      );
                      _previewAt(details.globalPosition);
                    },
                    onDragEnd: (details) => _finish(details, item.child),
                    feedback: SizedBox(
                      width: widget.cardWidth,
                      height: widget.cardHeight,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 1,
                          end: MediaQuery.disableAnimationsOf(context)
                              ? 1
                              : 1.03,
                        ),
                        duration: KoinMotion.duration(
                          context,
                          const Duration(milliseconds: 160),
                        ),
                        curve: _curve,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: Material(
                            color: Colors.transparent,
                            elevation: 12,
                            borderRadius: BorderRadius.circular(
                              KoinShape.field,
                            ),
                            child: child,
                          ),
                        ),
                        child: IgnorePointer(child: item.child),
                      ),
                    ),
                    childWhenDragging: _placeholder(context),
                    child: _draggedId == item.id
                        ? _placeholder(context)
                        : item.child,
                  ),
                ),
              ),
            Positioned(
              left: _slot(widget.items.length).dx,
              top: _slot(widget.items.length).dy,
              width: widget.cardWidth,
              height: widget.cardHeight,
              child: widget.addButton,
            ),
          ],
        ),
      ),
    );
  }
}
