import 'package:archiveme_mobile/features/session_movement/session_movement_models.dart';

abstract final class BreakthroughShiftDetector {
  BreakthroughShiftDetector._();

  static const confidenceDeltaThreshold = 10;

  static bool isBreakthroughMovement(SessionMovementKind kind) {
    return switch (kind) {
      SessionMovementKind.beliefChanged ||
      SessionMovementKind.beliefWeakened ||
      SessionMovementKind.beliefStrengthened ||
      SessionMovementKind.contradictionAppeared =>
        true,
      _ => false,
    };
  }

  static bool isBreakthroughSummary(SessionMovementSummaryView summary) {
    if (summary.kind == SessionMovementKind.beliefChanged) return true;
    if (isBreakthroughMovement(summary.kind)) return true;
    final delta = _parseConfidenceDelta(summary.detailLine);
    return delta != null && delta >= confidenceDeltaThreshold;
  }

  static int? _parseConfidenceDelta(String? detailLine) {
    if (detailLine == null) return null;
    final match = RegExp(r'(\d+)%\s*→\s*(\d+)%').firstMatch(detailLine);
    if (match == null) return null;
    final from = int.tryParse(match.group(1) ?? '');
    final to = int.tryParse(match.group(2) ?? '');
    if (from == null || to == null) return null;
    return (to - from).abs();
  }
}

abstract final class BreakthroughFeedCopy {
  BreakthroughFeedCopy._();

  static const eyebrow = 'Breakthrough';
  static const title = 'Something meaningful shifted in your archive';
  static const body =
      'This is a high-signal change — worth revisiting when you have a quiet moment.';
}