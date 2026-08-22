import 'package:archiveme_mobile/features/comparison_engine/comparison_engine.dart';
import 'package:archiveme_mobile/features/comparison_engine/comparison_engine_model.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/comparison_manifest_formatter.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/controllers/post_save_comparison_controller.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Local model client that evaluates comparisons from saved journal entries.
class JournalComparisonModelApiClient implements ModelApiClient {
  JournalComparisonModelApiClient({
    required List<JournalEntry> entries,
    this._engine = const ComparisonEngine(),
  }) : _entries = List<JournalEntry>.from(entries);

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