import '../../../../models/journal_entry.dart';
import '../../../../models/reflection.dart';
import '../../../../models/sync_status.dart';
import '../../comparison_engine.dart';
import '../../comparison_engine_model.dart';
import '../models/archive_moment_record.dart';

class LocalTextComparisonResult {
  const LocalTextComparisonResult({
    required this.alignmentState,
    required this.connectionSummary,
    required this.matchedPastQuote,
    required this.matchedCurrentQuote,
    required this.evolutionAnalysis,
  });

  final PatternState alignmentState;
  final String connectionSummary;
  final String matchedPastQuote;
  final String matchedCurrentQuote;
  final String evolutionAnalysis;
}

/// Deterministic local comparison over pruned [ArchiveMomentRecord] history.
class LocalTextComparisonEngine {
  const LocalTextComparisonEngine({this._engine = const ComparisonEngine()});

  final ComparisonEngine _engine;

  LocalTextComparisonResult buildFromRawTextHistory({
    required ArchiveMomentRecord current,
    required List<ArchiveMomentRecord> history,
  }) {
    if (history.isEmpty) {
      throw StateError('Local comparison requires historical context.');
    }

    final chronological = List<ArchiveMomentRecord>.from(history)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final pastMoment = chronological.last;
    final entries = [
      for (final moment in chronological) _journalEntryFromMoment(moment),
      _journalEntryFromMoment(current),
    ];

    final result = _engine.buildFromRawTextHistory(entries);
    final pastQuote = pastMoment.savedWords.trim();
    final currentQuote = current.savedWords.trim();

    if (!result.isRelated || result.output == null) {
      return LocalTextComparisonResult(
        alignmentState: PatternState.notEnoughEvidence,
        connectionSummary: 'A repeating thread may be forming.',
        matchedPastQuote: pastQuote,
        matchedCurrentQuote: currentQuote,
        evolutionAnalysis: 'ArchiveMe needs more moments to be sure.',
      );
    }

    final output = result.output!;
    final evolution = output.whatChanged?.trim();
    return LocalTextComparisonResult(
      alignmentState: _patternStateFromConfidence(output.confidenceLabel),
      connectionSummary:
          'This may connect to ${output.whatAppearsRepeated.trim()}.',
      matchedPastQuote: pastQuote,
      matchedCurrentQuote: currentQuote,
      evolutionAnalysis: evolution == null || evolution.isEmpty
          ? 'ArchiveMe needs more moments to be sure.'
          : evolution,
    );
  }

  static PatternState _patternStateFromConfidence(
    ComparisonConfidenceLabel label,
  ) {
    switch (label) {
      case ComparisonConfidenceLabel.earlySignal:
        return PatternState.earlySignal;
      case ComparisonConfidenceLabel.possibleRepeat:
        return PatternState.possibleRepeat;
      case ComparisonConfidenceLabel.clearRepeat:
        return PatternState.clearRepeat;
      case ComparisonConfidenceLabel.stillCurrent:
        return PatternState.stillCurrent;
      case ComparisonConfidenceLabel.fading:
        return PatternState.fading;
      case ComparisonConfidenceLabel.changed:
        return PatternState.changed;
      case ComparisonConfidenceLabel.softened:
        return PatternState.softened;
      case ComparisonConfidenceLabel.corrected:
        return PatternState.corrected;
      case ComparisonConfidenceLabel.notEnoughEvidence:
        return PatternState.notEnoughEvidence;
    }
  }

  static JournalEntry _journalEntryFromMoment(ArchiveMomentRecord moment) {
    return JournalEntry(
      id: moment.id,
      createdAt: moment.createdAt,
      transcript: moment.savedWords,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );
  }
}
