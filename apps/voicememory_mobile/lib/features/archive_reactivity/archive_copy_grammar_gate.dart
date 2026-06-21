import '../patterns/pattern_display_copy_gate.dart';
import 'archive_copy_normalizer.dart';

/// Archive-only grammar gate — always normalizes before display-copy logging.
abstract class ArchiveCopyGrammarGate {
  ArchiveCopyGrammarGate._();

  static PatternDisplayCopyCheckResult checkForDisplayLog({
    required PatternDisplayField field,
    required String text,
  }) {
    final normalized = ArchiveCopyNormalizer.normalize(text);
    if (normalized.isEmpty) {
      return PatternDisplayCopyGate.check(field, normalized);
    }
    if (ArchiveCopyNormalizer.hasResidualMalformedText(normalized)) {
      return PatternDisplayCopyCheckResult(
        copy: PatternDisplayCopyGate.fallbackFor(field),
        decision: PatternDisplayCopyDecision.rejected,
        reason: 'malformed_residual',
        approved: false,
      );
    }
    return PatternDisplayCopyGate.check(field, normalized);
  }

  static bool passes({
    required PatternDisplayField field,
    required String text,
  }) =>
      checkForDisplayLog(field: field, text: text).approved;

  static String displayOrFallback({
    required PatternDisplayField field,
    required String text,
  }) =>
      checkForDisplayLog(field: field, text: text).copy;
}
