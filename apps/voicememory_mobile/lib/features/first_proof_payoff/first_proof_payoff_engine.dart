import '../../models/journal_entry.dart';
import '../archive_controls/archive_exclusion_engine.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/archive_pattern_copy_guard.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../chat_differentiation/chat_differentiation_copy.dart';
import '../chat_differentiation/chat_differentiation_engine.dart';
import '../pattern_detail/pattern_detail_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'first_proof_payoff_copy.dart';
import 'first_proof_payoff_model.dart';

/// Builds the first proof emotional payoff from existing grounded evidence only.
abstract final class FirstProofPayoffEngine {
  FirstProofPayoffEngine._();

  static const _maxSnippetChars = 72;
  static const _minSnippetChars = 12;

  static FirstProofPayoff? build({
    required List<JournalEntry> entries,
    bool viewingConfirmedRepeatOrTimeline = true,
  }) {
    if (!ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return null;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return null;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return null;
    }

    final eligible = ArchiveExclusionEngine.eligibleForActivePattern(entries);
    if (eligible.length != 3) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(eligible)) {
      return null;
    }

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      evidence.phrases,
      eligible,
    );
    if (grounded.isEmpty) return null;

    final primaryPhrase = grounded.first.trim();
    final snippets = _buildSnippets(eligible, grounded);
    final hasStrongEvidence = evidence.isStrong && grounded.isNotEmpty;
    final variant = snippets.length >= 2
        ? FirstProofPayoffVariant.strongWithSnippets
        : FirstProofPayoffVariant.fallbackPhraseOnly;

    final confirmedRepeat = EarlyFirstSignalEngine.build(entries: entries);
    final canShowPatternDetail = PatternDetailEngine.canShow(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );

    final hasSnippets = variant == FirstProofPayoffVariant.strongWithSnippets;
    final calibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: viewingConfirmedRepeatOrTimeline,
      source: 'first_proof_payoff',
    );

    return FirstProofPayoff(
      variant: variant,
      headline: hasSnippets
          ? FirstProofPayoffCopy.headline
          : (calibration.isWatchOnly || calibration.level == ProofConfidenceLevel.emerging
              ? FirstProofPayoffCopy.fallbackHeadline
              : FirstProofPayoffCopy.fallbackHeadline),
      subhead: '',
      groundedPhrase: primaryPhrase,
      evidenceLabel: FirstProofPayoffCopy.yourWordsLabel,
      snippets: snippets,
      meaningLine: hasSnippets && !calibration.isWatchOnly
          ? FirstProofPayoffCopy.patternLine
          : '',
      returnHook: hasSnippets
          ? (calibration.level == ProofConfidenceLevel.strong
              ? calibration.primaryCopy
              : FirstProofPayoffCopy.truthLine)
          : calibration.primaryCopy,
      hasStrongEvidence: hasStrongEvidence,
      canShowPatternDetail: canShowPatternDetail,
      differentiationLine: hasSnippets
          ? ChatDifferentiationCopy.firstProofLine
          : null,
      timelineRows: hasSnippets
          ? ChatDifferentiationEngine.timelineFromEntries(eligible)
          : const [],
    );
  }

  static List<FirstProofEvidenceSnippet> _buildSnippets(
    List<JournalEntry> entries,
    List<String> groundedPhrases,
  ) {
    final snippets = <FirstProofEvidenceSnippet>[];
    for (final entry in entries) {
      if (snippets.length >= 3) break;
      if (!ComparableEvidenceText.entryHasComparableEvidence(entry)) continue;

      final text = ComparableEvidenceText.userText(entry);
      if (text.isEmpty) continue;
      if (ArchivePatternCopyGuard.isBlockedPatternText(text)) continue;

      final quote = _quoteForEntry(text, groundedPhrases);
      if (quote == null) continue;

      snippets.add(FirstProofEvidenceSnippet(label: '', quote: quote));
    }
    return snippets;
  }

  static String? _quoteForEntry(String text, List<String> phrases) {
    final trimmed = text.trim();
    if (trimmed.length < _minSnippetChars) return null;

    for (final phrase in phrases) {
      final normalized = phrase.trim();
      if (normalized.isEmpty) continue;
      final index = trimmed.toLowerCase().indexOf(normalized.toLowerCase());
      if (index < 0) continue;

      final start = _snippetStart(trimmed, index);
      final end = _snippetEnd(trimmed, index + normalized.length);
      final slice = trimmed.substring(start, end).trim();
      if (slice.length < _minSnippetChars) continue;
      return _trimSnippet(slice);
    }

    if (trimmed.length < _minSnippetChars) return null;
    return _trimSnippet(trimmed);
  }

  static int _snippetStart(String text, int matchIndex) {
    final sentenceStart = text.lastIndexOf('.', matchIndex);
    final windowStart = matchIndex > 24 ? matchIndex - 24 : 0;
    final start = sentenceStart >= 0 ? sentenceStart + 1 : windowStart;
    return start.clamp(0, matchIndex);
  }

  static int _snippetEnd(String text, int matchEnd) {
    final sentenceEnd = text.indexOf('.', matchEnd);
    final windowEnd = (matchEnd + 32).clamp(0, text.length);
    final end = sentenceEnd >= 0 ? sentenceEnd : windowEnd;
    return end.clamp(matchEnd, text.length);
  }

  static String _trimSnippet(String snippet) {
    final cleaned = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _maxSnippetChars) return cleaned;
    return '${cleaned.substring(0, _maxSnippetChars - 1).trim()}…';
  }
}
