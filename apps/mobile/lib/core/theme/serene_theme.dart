import 'package:flutter/material.dart';

/// Pastel surfaces, soft shadows, and the type scale entry cards read from
/// [ThemeData.textTheme].
abstract final class SereneTheme {
  static const Color mist = Color(0xFFF7F1EA);
  static const Color foam = Color(0xFFE7F0F4);
  static const Color blush = Color(0xFFF3E8F2);
  static const Color ink = Color(0xFF3E4A55);

  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mist, foam, blush],
  );

  /// 6% ink. Soft enough to lift a card without a hard edge.
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0F3E4A55),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static TextTheme textTheme(Color color) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.6,
        color: color,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: color,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
        color: color,
      ),
    );
  }

  /// Keeps the current color scheme and replaces the type scale.
  static ThemeData overlay(ThemeData base) {
    final color = base.colorScheme.onSurface;
    return base.copyWith(
      textTheme: textTheme(color),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        shadowColor: const Color(0x143E4A55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// Fade-and-rise used when a card or pill first appears.
class SereneEntrance extends StatefulWidget {
  const SereneEntrance({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SereneEntrance> createState() => _SereneEntranceState();
}

class _SereneEntranceState extends State<SereneEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: rise, child: widget.child),
    );
  }
}
