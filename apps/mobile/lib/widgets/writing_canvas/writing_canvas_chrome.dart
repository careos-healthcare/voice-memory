import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hides secondary canvas chrome while writing; restores on idle or scroll-up.
class WritingCanvasChromeController extends ChangeNotifier {
  WritingCanvasChromeController({
    this.idleRestore = const Duration(milliseconds: 1800),
  });

  final Duration idleRestore;

  var _visible = true;
  Timer? _idle;

  bool get isChromeVisible => _visible;

  void onTyped({required bool hasText, required bool focused}) {
    if (focused && hasText) {
      _setVisible(false);
      _restartIdle();
      return;
    }
    if (!hasText) {
      _idle?.cancel();
      _setVisible(true);
    }
  }

  /// Negative [scrollDelta] is a scroll-up (earlier content coming into view).
  void onScrollDelta(double scrollDelta) {
    if (scrollDelta < -2) {
      _idle?.cancel();
      _setVisible(true);
    } else if (scrollDelta > 6 && !_visible) {
      _restartIdle();
    } else if (scrollDelta > 6) {
      _setVisible(false);
    }
  }

  void restoreChrome() {
    _idle?.cancel();
    _setVisible(true);
  }

  void _restartIdle() {
    _idle?.cancel();
    if (_disposed) return;
    if (idleRestore <= Duration.zero) {
      _setVisible(true);
      return;
    }
    _idle = Timer(idleRestore, restoreChrome);
  }

  void _setVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    notifyListeners();
  }

  var _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _idle?.cancel();
    super.dispose();
  }
}

/// Fades [child] when the canvas chrome controller hides secondary UI.
class WritingCanvasChromeFade extends StatelessWidget {
  const WritingCanvasChromeFade({
    super.key,
    required this.controller,
    required this.child,
  });

  final WritingCanvasChromeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final visible = controller.isChromeVisible;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            key: const Key('writing_canvas_chrome_fade'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: visible ? 1 : 0,
            child: child,
          ),
        );
      },
    );
  }
}
