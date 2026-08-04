import 'package:flutter/material.dart';

/// A secondary post-save action whose label wraps instead of clipping.
///
/// At the largest text scale a fixed-width button label is the first thing to
/// overflow on a narrow phone, so the label is explicitly bounded by the space
/// the row actually has and allowed to wrap onto a second line.
class PostSaveActionButton extends StatelessWidget {
  const PostSaveActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.outlined = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Announced to a screen reader as the selected state of a choice.
  final bool selected;

  /// Outlined for a choice, plain text for a way out of the surface.
  final bool outlined;

  static const _minimumTarget = Size(48, 48);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.maxWidth;
      final labelWidth = available.isFinite
          ? (available - 56).clamp(64.0, 480.0)
          : 480.0;
      final content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: labelWidth),
        child: Text(label, softWrap: true, textAlign: TextAlign.center),
      );
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: outlined
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  minimumSize: _minimumTarget,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                ),
                child: content,
              )
            : TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(minimumSize: _minimumTarget),
                child: content,
              ),
      );
    },
  );
}
