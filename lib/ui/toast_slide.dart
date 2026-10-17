import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const toastSlideIn = Duration(milliseconds: 420);
const toastSlideOut = Duration(milliseconds: 240);

/// Slides its child in from the right screen edge while [visible] is true,
/// and back out when it turns false. The window itself is transparent, so
/// this reads as the pop-up driving in from off-screen.
class ToastSlide extends StatefulWidget {
  const ToastSlide({super.key, required this.visible, required this.child});

  final ValueListenable<bool> visible;
  final Widget child;

  @override
  State<ToastSlide> createState() => _ToastSlideState();
}

class _ToastSlideState extends State<ToastSlide>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: toastSlideIn,
    reverseDuration: toastSlideOut,
    value: widget.visible.value ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    // No overshoot: the window is exactly card-sized, so overshooting
    // would clip the card's left edge.
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _offset = Tween(
    begin: const Offset(1.1, 0),
    end: Offset.zero,
  ).animate(_curve);

  @override
  void initState() {
    super.initState();
    widget.visible.addListener(_sync);
  }

  @override
  void didUpdateWidget(ToastSlide old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) {
      old.visible.removeListener(_sync);
      widget.visible.addListener(_sync);
      _sync();
    }
  }

  void _sync() =>
      widget.visible.value ? _controller.forward() : _controller.reverse();

  @override
  void dispose() {
    widget.visible.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _offset,
    child: FadeTransition(
      opacity: _controller.drive(CurveTween(curve: const Interval(0, 0.5))),
      child: widget.child,
    ),
  );
}
