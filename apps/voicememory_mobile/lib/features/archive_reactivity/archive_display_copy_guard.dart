import '../patterns/pattern_display_copy_gate.dart';
import 'archive_copy_grammar_gate.dart';
import 'archive_copy_minimum_bar.dart';
import 'archive_copy_normalizer.dart';

/// Unified archive display-copy pipeline: normalize, grammar gate, minimum bar.
abstract class ArchiveDisplayCopyGuard {
  ArchiveDisplayCopyGuard._();

  static const malformedLogTokens = ArchiveCopyNormalizer.residualMalformedTokens;

  static String normalize(String text) => ArchiveCopyNormalizer.normalize(text);

  static PatternDisplayCopyCheckResult checkForDisplayLog({
    required PatternDisplayField field,
    required String text,
  }) =>
      ArchiveCopyGrammarGate.checkForDisplayLog(field: field, text: text);

  static String validateAndNormalize({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) {
    final normalized = ArchiveCopyNormalizer.normalize(text);
    if (normalized.isEmpty) return '';

    final result = ArchiveCopyMinimumBar.validateNormalized(
      field: field,
      normalizedText: normalized,
      allowShortLabel: allowShortLabel,
      requireSpecificity: requireSpecificity,
      allowGenericFallback: allowGenericFallback,
    );
    return result.approved ? result.normalizedText : '';
  }

  static bool passesGrammarGate({
    required PatternDisplayField field,
    required String text,
  }) =>
      ArchiveCopyGrammarGate.passes(field: field, text: text);

  static String grammarDisplayOrFallback({
    required PatternDisplayField field,
    required String text,
  }) =>
      ArchiveCopyGrammarGate.displayOrFallback(field: field, text: text);

  static bool passesCombinedGate({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) =>
      validateAndNormalize(
        field: field,
        text: text,
        allowShortLabel: allowShortLabel,
        requireSpecificity: requireSpecificity,
        allowGenericFallback: allowGenericFallback,
      ).isNotEmpty;

  static ArchiveCopyMinimumResult inspect({
    required String field,
    required String text,
    bool allowShortLabel = false,
    bool requireSpecificity = true,
    bool allowGenericFallback = false,
  }) =>
      ArchiveCopyMinimumBar.validate(
        field: field,
        text: text,
        allowShortLabel: allowShortLabel,
        requireSpecificity: requireSpecificity,
        allowGenericFallback: allowGenericFallback,
      );
}
