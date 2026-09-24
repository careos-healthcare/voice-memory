import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Light haptic + a short spring scale for primary canvas actions.
abstract final class WritingCanvasPress {
  WritingCanvasPress._();

  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 18);

  static VoidCallback? wrap(VoidCallback? action) {
    if (action == null) return null;
    return () {
      HapticFeedback.lightImpact();
      action();
    };
  }
}

/// Scales its child with a subtle spring when pressed.
class WritingCanvasSpringHost extends StatefulWidget {
  const WritingCanvasSpringHost({super.key, required this.child});

  final Widget child;

  @override
  State<WritingCanvasSpringHost> createState() =>
      _WritingCanvasSpringHostState();
}

class _WritingCanvasSpringHostState extends State<WritingCanvasSpringHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)..value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    _controller.animateWith(
      SpringSimulation(WritingCanvasPress.spring, _controller.value, 0.96, 0),
    );
  }

  void _release() {
    _controller.animateWith(
      SpringSimulation(WritingCanvasPress.spring, _controller.value, 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value.clamp(0.92, 1.04),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
