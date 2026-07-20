import '../../../models/journal_entry.dart';
import '../comparison_engine.dart';
import '../comparison_engine_model.dart';
import '../domain/services/comparison_manifest_formatter.dart';
import '../presentation/controllers/post_save_comparison_controller.dart';

/// Local model client that evaluates comparisons from saved journal entries.
class JournalComparisonModelApiClient implements ModelApiClient {
  JournalComparisonModelApiClient({
    required List<JournalEntry> entries,
    ComparisonEngine engine = const ComparisonEngine(),
  })  : _entries = List<JournalEntry>.from(entries),
        _engine = engine;

  final List<JournalEntry> _entries;
  final ComparisonEngine _engine;

  @override
  Future<String> evaluatePrompts({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    if (_entries.length < 2) {
      return ComparisonManifestFormatter.format(
        result: ComparisonEngineResult.insufficient,
        pastEntry: _entries.first,
        currentEntry: _entries.last,
      );
    }

    final result = _engine.buildFromRawTextHistory(_entries);
    return ComparisonManifestFormatter.format(
      result: result,
      pastEntry: _entries[_entries.length - 2],
      currentEntry: _entries.last,
    );
  }
}
