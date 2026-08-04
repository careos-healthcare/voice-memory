import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pattern_detail/pattern_detail_engine.dart';
import '../pattern_detail/pattern_detail_model.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../pattern_naming/pattern_name_store.dart';
import 'share_card_model.dart';

/// Builds privacy-safe share card content from grounded pattern evidence.
abstract final class ShareCardBuilder {
  ShareCardBuilder._();

  static const _sensitiveLabelMaxLength = 50;

  static bool canShow({
    required List<JournalEntry> entries,
    PatternDetailResult? detail,
    EarlyFirstSignalModel? confirmedRepeat,
    bool viewingConfirmedRepeatOrTimeline = true,
  }) =>
      build(
        entries: entries,
        detail: detail,
        confirmedRepeat: confirmedRepeat,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      ) !=
      null;

  static ShareCardModel? build({
    required List<JournalEntry> entries,
    PatternDetailResult? detail,
    EarlyFirstSignalModel? confirmedRepeat,
    bool viewingConfirmedRepeatOrTimeline = true,
  }) {
    if (!_allowsGroundedPattern(entries, viewingConfirmedRepeatOrTimeline)) {
      return null;
    }

    final resolvedDetail =
        detail ??
        PatternDetailEngine.build(
          entries: entries,
          confirmedRepeat: confirmedRepeat,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
        );
    if (resolvedDetail == null) return null;

    final groundedPhrase = _primaryGroundedPhrase(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      detail: resolvedDetail,
    );
    if (groundedPhrase == null || groundedPhrase.trim().isEmpty) return null;

    final patternKey = PatternNameEngine.patternKey(groundedPhrase);
    final displayLabel = resolvedDetail.patternLabel.trim().isNotEmpty
        ? resolvedDetail.patternLabel.trim()
        : PatternNameEngine.displayLabelForGroundedPhrase(groundedPhrase);

    final relatedCount = _relatedMomentCount(
      detail: resolvedDetail,
      entries: entries,
    );
    if (relatedCount <= 0) return null;

    return ShareCardModel(
      patternKey: patternKey,
      displayPatternLabel: displayLabel,
      relatedMomentCount: relatedCount,
      hasChangeNoticed: resolvedDetail.whatChangedSupported,
      labelNeedsReview: isLabelTooSensitive(
        patternKey: patternKey,
        displayLabel: displayLabel,
        groundedPhrase: groundedPhrase,
      ),
      entryCount: entries.length,
      groundedPhrase: groundedPhrase,
    );
  }

  static bool isLabelTooSensitive({
    required String patternKey,
    required String displayLabel,
    required String groundedPhrase,
  }) {
    if (PatternNameStore.hasCustomName(patternKey)) return false;
    final trimmed = displayLabel.trim();
    if (trimmed.isEmpty) return true;
    if (_containsContactInfo(trimmed)) return true;
    if (trimmed.toLowerCase() == groundedPhrase.trim().toLowerCase()) {
      return true;
    }
    if (trimmed.length > _sensitiveLabelMaxLength) return true;
    return false;
  }

  static String? sanitizeDisplayLabel(String raw) {
    final trimmed = PatternNameStore.normalizeCustomName(raw);
    if (trimmed == null || trimmed.isEmpty) return null;
    if (_containsContactInfo(trimmed)) return null;
    return trimmed;
  }

  static bool _allowsGroundedPattern(
    List<JournalEntry> entries,
    bool viewingConfirmedRepeatOrTimeline,
  ) {
    if (!viewingConfirmedRepeatOrTimeline) return false;
    if (entries.isEmpty) return false;
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
  }

  static String? _primaryGroundedPhrase({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    required PatternDetailResult detail,
  }) {
    if (detail.evidencePhrases.isNotEmpty) {
      return detail.evidencePhrases.first;
    }
    final signal =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: entries);
    if (signal?.evidencePhrases.isNotEmpty == true) {
      return signal!.evidencePhrases.first;
    }
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return null;
    final phrases = ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    ).phrases;
    return phrases.isEmpty ? null : phrases.first;
  }

  static int _relatedMomentCount({
    required PatternDetailResult detail,
    required List<JournalEntry> entries,
  }) {
    if (detail.savedMoments.isNotEmpty) return detail.savedMoments.length;
    final strong = ArchiveEvidenceQualityGate.strongCount(entries);
    if (strong >= 3) return strong;
    return ArchiveEvidenceQualityGate.usableCount(entries);
  }

  static bool _containsContactInfo(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'@[\w.-]+\.\w{2,}').hasMatch(lower)) return true;
    if (RegExp(r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b').hasMatch(text)) {
      return true;
    }
    return false;
  }
}
