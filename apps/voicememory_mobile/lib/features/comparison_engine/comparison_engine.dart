import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../retention/second_session_signal_engine.dart';
import '../retention/second_session_signal_model.dart';
import 'comparison_engine_model.dart';
import 'comparison_engine_prompt.dart';

/// Deterministic comparison engine — structured, evidence-only output.
class ComparisonEngine {
  const ComparisonEngine();

  static const _signalEngine = SecondSessionSignalEngine();

  ComparisonEngineResult build(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsEarlyComparisons(entries)) {
      return ComparisonEngineResult.insufficient;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) {
      return ComparisonEngineResult.insufficient;
    }

    final signal = _signalEngine.build(entries);
    if (!signal.hasEnoughData || !signal.possibleRepeat) {
      return ComparisonEngineResult.unrelated;
    }

    if (!_signalEngine.hasGroundedRepeatMatch(entries)) {
      return ComparisonEngineResult.unrelated;
    }

    return _buildRelatedResult(entries: entries, signal: signal);
  }

  /// Text-first comparison for post-save pipeline — no clinical quality or
  /// grounded-repeat gates. Caller enforces only baseline history sanity.
  ComparisonEngineResult buildFromRawTextHistory(List<JournalEntry> entries) {
    if (entries.length < 2) {
      return ComparisonEngineResult.insufficient;
    }

    final signal = _signalEngine.build(entries);
    if (!signal.hasEnoughData || !signal.possibleRepeat) {
      return ComparisonEngineResult.unrelated;
    }

    return _buildRelatedResult(entries: entries, signal: signal);
  }

  ComparisonEngineResult _buildRelatedResult({
    required List<JournalEntry> entries,
    required SecondSessionComparison signal,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final previous = eligible.length >= 2
        ? eligible[eligible.length - 2]
        : entries[entries.length - 2];
    final latest = eligible.isNotEmpty ? eligible.last : entries.last;

    final rawRepeated =
        _usableLine(signal.whatRepeated) ??
        'something similar across your last two moments';
    final rawChanged = _usableLine(signal.whatChanged);

    final whatAppearsRepeated = ComparisonEnginePrompt.sanitizeLine(
      rawRepeated,
      fallback: 'something similar may be showing up across both moments',
    );
    final whatChanged = rawChanged == null
        ? null
        : ComparisonEnginePrompt.sanitizeLine(
            rawChanged,
            fallback:
                'The latest moment may sit differently from the one before it.',
          );

    final confidence = _resolveConfidence(
      signal: signal,
      whatChanged: whatChanged,
      previousLabel: signal.previousSignalLabel,
      latestLabel: signal.latestSignalLabel,
    );
    final thinEvidence = _thinEvidencePhrase(confidence);

    return ComparisonEngineResult(
      hasComparison: true,
      isRelated: true,
      output: ComparisonEngineOutput(
        confidenceLabel: confidence,
        whatAppearsRepeated: whatAppearsRepeated,
        connectedMomentDayTime: _connectedMomentLabel(previous),
        connectedEntryId: previous.id,
        whatChanged: whatChanged,
        thinEvidencePhrase: thinEvidence,
        pastQuote: _evidenceQuote(previous),
        presentQuote: _evidenceQuote(latest),
      ),
    );
  }

  ComparisonConfidenceLabel _resolveConfidence({
    required SecondSessionComparison signal,
    required String? whatChanged,
    required String? previousLabel,
    required String? latestLabel,
  }) {
    final changeLabel = _changeConfidence(whatChanged);
    if (changeLabel != null) return changeLabel;

    if (previousLabel != null &&
        latestLabel != null &&
        previousLabel.trim().toLowerCase() ==
            latestLabel.trim().toLowerCase()) {
      return ComparisonConfidenceLabel.stillCurrent;
    }

    if (signal.possibleRepeat == true &&
        signal.previousSignalLabel != null &&
        signal.latestSignalLabel != null) {
      return ComparisonConfidenceLabel.clearRepeat;
    }

    return ComparisonConfidenceLabel.possibleRepeat;
  }

  ComparisonConfidenceLabel? _changeConfidence(String? whatChanged) {
    final line = whatChanged?.trim().toLowerCase() ?? '';
    if (line.isEmpty) return null;
    if (line.contains('soft') ||
        line.contains('lighter') ||
        line.contains('distance') ||
        line.contains('calmer')) {
      return ComparisonConfidenceLabel.softened;
    }
    if (line.contains('chang') ||
        line.contains('different') ||
        line.contains('more about') ||
        line.contains('shift')) {
      return ComparisonConfidenceLabel.changed;
    }
    return null;
  }

  String? _thinEvidencePhrase(ComparisonConfidenceLabel confidence) {
    switch (confidence) {
      case ComparisonConfidenceLabel.earlySignal:
      case ComparisonConfidenceLabel.possibleRepeat:
      case ComparisonConfidenceLabel.notEnoughEvidence:
        return ComparisonEnginePrompt.thinEvidenceDefault;
      case ComparisonConfidenceLabel.clearRepeat:
      case ComparisonConfidenceLabel.stillCurrent:
      case ComparisonConfidenceLabel.changed:
      case ComparisonConfidenceLabel.softened:
      case ComparisonConfidenceLabel.fading:
      case ComparisonConfidenceLabel.corrected:
        return null;
    }
  }

  String _evidenceQuote(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    if (transcript.isNotEmpty) return transcript;
    final observation = entry.reflection.concreteObservation.trim();
    if (observation.isNotEmpty) return observation;
    return '';
  }

  String? _usableLine(String? line) {
    final trimmed = line?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatRepeated) {
      return null;
    }
    if (trimmed == ConsumerUiCopy.secondSessionFallbackWhatChanged) {
      return null;
    }
    return trimmed;
  }

  String _connectedMomentLabel(JournalEntry entry) {
    final local = entry.createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${formatUserFacingDate(entry.createdAt)} · $displayHour:$minute $period';
  }
}
