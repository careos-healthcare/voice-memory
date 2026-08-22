import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/comparison_engine/comparison_engine_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

abstract final class ComparisonManifestFormatter {
  ComparisonManifestFormatter._();

  static String format({
    required ComparisonEngineResult result,
    required JournalEntry pastEntry,
    required JournalEntry currentEntry,
  }) {
    final output = result.output;
    if (output == null || !result.isRelated) {
      return _manifesto(
        label: ComparisonConfidenceLabel.notEnoughEvidence.label,
        connection: '',
        pastQuote: _quote(pastEntry),
        presentQuote: _quote(currentEntry),
        whatChanged: '',
      );
    }

    final changed = output.whatChanged?.trim();
    return _manifesto(
      label: output.confidenceLabel.label,
      connection: 'This may connect to ${output.whatAppearsRepeated.trim()}.',
      pastQuote: _quote(pastEntry),
      presentQuote: _quote(currentEntry),
      whatChanged: changed == null || changed.isEmpty
          ? 'ArchiveMe needs more moments to be sure.'
          : changed,
    );
  }

  static String _quote(JournalEntry entry) =>
      ComparableEvidenceText.userText(entry);

  static String _manifesto({
    required String label,
    required String connection,
    required String pastQuote,
    required String presentQuote,
    required String whatChanged,
  }) {
    return '''
---
Label: $label
Connection: $connection
Evidence:
- Past: "$pastQuote"
- Present: "$presentQuote"
What Changed: $whatChanged
---
''';
  }
}