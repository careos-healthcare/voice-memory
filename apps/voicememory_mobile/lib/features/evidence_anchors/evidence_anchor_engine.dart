import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_timeline_spine/archive_timeline_spine_model.dart';
import '../correction_memory/correction_memory_copy.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_archive_insight_quality_engine.dart';
import '../early_archive/early_first_signal_copy.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_weighting/evidence_weighting_copy.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../present_day_relevance/present_day_relevance_copy.dart';
import '../present_day_relevance/present_day_relevance_engine.dart';
import '../present_day_relevance/present_day_relevance_model.dart';
import '../anchor_calibration/anchor_calibration_engine.dart';
import '../timeline/timeline_entry_display.dart';
import 'evidence_anchor_analytics.dart';
import 'evidence_anchor_copy.dart';
import 'evidence_anchor_model.dart';

/// Extracts typed safe evidence anchors from existing engines only.
abstract final class EvidenceAnchorEngine {
  EvidenceAnchorEngine._();

  static const minEntryCount = 3;
  static const maxAnchors = 3;
  static const maxAnchorLength = 72;
  static const recentWindowDays = 7;

  static const _typePriority = AnchorCalibrationEngine.typePriority;

  static EvidenceAnchorExtractionResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
    DateTime? now,
    EvidenceWeightingResult? evidenceWeighting,
    PresentDayRelevanceResult? presentDay,
    CorrectionMemorySnapshot? correction,
    bool trackAnalytics = false,
  }) {
    if (entries.length < minEntryCount) {
      return EvidenceAnchorExtractionResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) {
      return EvidenceAnchorExtractionResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (!_passesEvidenceQuality(entries)) {
      return EvidenceAnchorExtractionResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final clock = now ?? DateTime.now();
    final weighting = evidenceWeighting ??
        EvidenceWeightingEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          now: clock,
        );
    final presentDayRelevance = presentDay ??
        PresentDayRelevanceEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: source,
          now: clock,
          evidenceWeighting: weighting,
        );
    final correctionSnapshot = correction ??
        CorrectionMemoryEngine.snapshotFor(
          entries: entries,
          now: clock,
        );

    final candidates = _collectCandidates(
      entries: entries,
      beliefEvidencePhrases: beliefEvidencePhrases,
      evidenceWeighting: weighting,
      presentDay: presentDayRelevance,
      correction: correctionSnapshot,
      now: clock,
    );

    final ranked = _rankCandidates(candidates);
    final selected = ranked.take(maxAnchors).toList();
    final safeSummaries = selected
        .where((anchor) => anchor.isSafeForDisplay)
        .map((anchor) => anchor.safeSummary)
        .toList();

    final hasSafeAnchor = safeSummaries.isNotEmpty;
    final usesFallback = !hasSafeAnchor;
    final anchors = hasSafeAnchor
        ? selected
        : [
            _fallbackAnchor(),
          ];

    final result = EvidenceAnchorExtractionResult(
      shouldExtract: true,
      entryCount: entries.length,
      source: source,
      anchors: anchors,
      safeSummaries: safeSummaries,
      usesFallback: usesFallback,
      hasSafeAnchor: hasSafeAnchor,
      hasRecentAnchor: selected.any((anchor) => anchor.recencyWeight >= 0.7),
      hasCorrectionAnchor: selected.any(
        (anchor) =>
            anchor.isUserCorrected ||
            anchor.type == EvidenceAnchorType.corrected ||
            anchor.type == EvidenceAnchorType.freshReturn,
      ),
      hasChangeAnchor: selected.any(
        (anchor) =>
            anchor.type == EvidenceAnchorType.change ||
            anchor.type == EvidenceAnchorType.softening ||
            anchor.type == EvidenceAnchorType.strengthening ||
            anchor.type == EvidenceAnchorType.helped ||
            anchor.type == EvidenceAnchorType.avoided,
      ),
    );

    if (trackAnalytics) {
      EvidenceAnchorAnalytics.trackExtraction(result: result);
    }

    return result;
  }

  @visibleForTesting
  static EvidenceAnchorExtractionResult fallbackResult({
    required String source,
    required int entryCount,
  }) =>
      EvidenceAnchorExtractionResult(
        shouldExtract: true,
        entryCount: entryCount,
        source: source,
        anchors: [_fallbackAnchor()],
        safeSummaries: const [],
        usesFallback: true,
        hasSafeAnchor: false,
        hasRecentAnchor: false,
        hasCorrectionAnchor: false,
        hasChangeAnchor: false,
      );

  static List<String> safeSummariesFor({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
    DateTime? now,
  }) =>
      build(
        entries: entries,
        beliefSurfaceVisible: beliefSurfaceVisible,
        source: source,
        beliefEvidencePhrases: beliefEvidencePhrases,
        now: now,
      ).safeSummaries;

  static List<ArchiveTimelineSpineRowAnchorHint> spineHintsFor({
    required List<EvidenceAnchor> anchors,
  }) {
    EvidenceAnchor? pick(EvidenceAnchorType type) {
      for (final anchor in anchors) {
        if (anchor.type == type && anchor.isSafeForDisplay) return anchor;
      }
      return null;
    }

    EvidenceAnchor? pickAny(Iterable<EvidenceAnchorType> types) {
      for (final type in types) {
        final anchor = pick(type);
        if (anchor != null) return anchor;
      }
      return null;
    }

    return [
      if (pick(EvidenceAnchorType.repeat) case final anchor?)
        ArchiveTimelineSpineRowAnchorHint(
          rowId: ArchiveTimelineSpineRowId.returned,
          anchorType: anchor.type,
          detail: anchor.safeSummary,
        ),
      if (pickAny(const [
        EvidenceAnchorType.current,
        EvidenceAnchorType.strengthening,
      ]) case final anchor?)
        ArchiveTimelineSpineRowAnchorHint(
          rowId: ArchiveTimelineSpineRowId.stillCurrent,
          anchorType: anchor.type,
          detail: anchor.safeSummary,
        ),
      if (pickAny(const [
        EvidenceAnchorType.corrected,
        EvidenceAnchorType.freshReturn,
      ]) case final anchor?)
        ArchiveTimelineSpineRowAnchorHint(
          rowId: ArchiveTimelineSpineRowId.correctedByYou,
          anchorType: anchor.type,
          detail: anchor.safeSummary,
        ),
      if (pickAny(const [
        EvidenceAnchorType.change,
        EvidenceAnchorType.softening,
        EvidenceAnchorType.strengthening,
        EvidenceAnchorType.helped,
        EvidenceAnchorType.avoided,
      ]) case final anchor?)
        ArchiveTimelineSpineRowAnchorHint(
          rowId: ArchiveTimelineSpineRowId.weightChanged,
          anchorType: anchor.type,
          detail: anchor.safeSummary,
        ),
      if (pick(EvidenceAnchorType.fading) case final anchor?)
        ArchiveTimelineSpineRowAnchorHint(
          rowId: ArchiveTimelineSpineRowId.needsFreshProof,
          anchorType: anchor.type,
          detail: anchor.safeSummary,
        ),
    ];
  }

  static List<_AnchorCandidate> _collectCandidates({
    required List<JournalEntry> entries,
    required List<String> beliefEvidencePhrases,
    required EvidenceWeightingResult? evidenceWeighting,
    required PresentDayRelevanceResult? presentDay,
    required CorrectionMemorySnapshot? correction,
    required DateTime now,
  }) {
    final candidates = <_AnchorCandidate>[];
    final privateTexts = _privateTextsFor(entries);
    var idCounter = 0;

    void add({
      required EvidenceAnchorType type,
      required String summary,
      double strength = 0.6,
      double recencyWeight = 0.5,
      int sourceCount = 1,
      bool isUserCorrected = false,
      bool isFreshReturn = false,
    }) {
      final safe = _sanitizeAnchor(
        summary,
        privateTexts: privateTexts,
        entryIds: entries.map((entry) => entry.id).toSet(),
      );
      if (safe == null) return;
      candidates.add(
        _AnchorCandidate(
          id: 'anchor_${idCounter++}',
          type: type,
          safeSummary: safe,
          strength: strength,
          recencyWeight: recencyWeight,
          sourceCount: sourceCount,
          isUserCorrected: isUserCorrected,
          isFreshReturn: isFreshReturn,
        ),
      );
    }

    for (final phrase in beliefEvidencePhrases) {
      add(
        type: _typeForPhrase(phrase),
        summary: phrase,
        strength: 0.75,
        recencyWeight: 0.55,
      );
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length >= 3) {
      final foundation = eligible.length >= 3
          ? eligible.sublist(0, 3)
          : eligible;
      final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(foundation);
      if (evidence.isStrong) {
        for (final phrase in ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
          evidence.phrases,
          foundation,
        )) {
          add(
            type: _typeForPhrase(phrase),
            summary: phrase,
            strength: 0.8,
            recencyWeight: _recencyWeightForEntries(foundation, now),
            sourceCount: foundation.length,
          );
        }
      }
    }

    final insight = EarlyArchiveInsightQualityEngine.build(entries: entries);
    final changeNotice = EarlyFirstSignalEngine.buildChangeNotice(entries: entries);
    if (changeNotice != null) {
      for (final line in changeNotice.evidenceLines) {
        add(
          type: line.toLowerCase().startsWith('change:')
              ? EvidenceAnchorType.change
              : EvidenceAnchorType.repeat,
          summary: line,
          strength: 0.85,
          recencyWeight: _recencyWeightForEntries(eligible, now),
        );
      }
      if (insight.softeningSummary != null) {
        add(
          type: EvidenceAnchorType.softening,
          summary: insight.softeningSummary!,
          strength: 0.82,
          recencyWeight: _recencyWeightForEntries(eligible, now),
        );
      }
    } else if (insight.softeningSummary != null) {
      add(
        type: EvidenceAnchorType.softening,
        summary: insight.softeningSummary!,
        strength: 0.78,
        recencyWeight: _recencyWeightForEntries(eligible, now),
      );
    }

    if (insight.helpfulActionSummary != null) {
      add(
        type: EvidenceAnchorType.helped,
        summary: insight.helpfulActionSummary!,
        strength: 0.8,
        recencyWeight: _recencyWeightForEntries(eligible, now),
      );
    }

    if (EarlyFirstSignalEngine.hasHelpfulActionEvidence(entries: entries)) {
      add(
        type: EvidenceAnchorType.helped,
        summary: EarlyFirstSignalCopy.helpfulActionCapturedEvidence,
        strength: 0.72,
        recencyWeight: _recencyWeightForEntries(eligible, now),
      );
    }

    if (evidenceWeighting?.hasSofteningSignal == true ||
        evidenceWeighting?.primaryState == EvidenceWeightState.softened) {
      add(
        type: EvidenceAnchorType.softening,
        summary: EarlyFirstSignalCopy.changeNoticeChangeEvidence,
        strength: 0.74,
        recencyWeight: evidenceWeighting?.hasRecentEntry == true ? 0.85 : 0.55,
      );
    }

    if (evidenceWeighting != null &&
        (evidenceWeighting.primaryState == EvidenceWeightState.repeated ||
            evidenceWeighting.primaryState == EvidenceWeightState.fresh ||
            correction?.state == CorrectionMemoryState.stillCurrent)) {
      add(
        type: EvidenceAnchorType.strengthening,
        summary: EvidenceWeightingCopy.explanationRepeated,
        strength: 0.7,
        recencyWeight: evidenceWeighting.hasRecentEntry ? 0.9 : 0.45,
        sourceCount: evidenceWeighting.hasRecentEntry ? 2 : 1,
      );
    }

    if (presentDay != null) {
      switch (presentDay.relevanceState) {
        case PresentDayRelevanceState.current:
          add(
            type: EvidenceAnchorType.current,
            summary: PresentDayRelevanceCopy.currentStateBody,
            strength: 0.76,
            recencyWeight: 0.88,
          );
        case PresentDayRelevanceState.fading:
          add(
            type: EvidenceAnchorType.fading,
            summary: PresentDayRelevanceCopy.fadingStateBody,
            strength: 0.68,
            recencyWeight: 0.25,
          );
        case PresentDayRelevanceState.softened:
          add(
            type: EvidenceAnchorType.softening,
            summary: PresentDayRelevanceCopy.softenedStateBody,
            strength: 0.72,
            recencyWeight: 0.7,
          );
        case PresentDayRelevanceState.unclear:
          break;
      }
    }

    if (correction != null) {
      if (correction.returnedAfterFaded) {
        add(
          type: EvidenceAnchorType.freshReturn,
          summary: CorrectionMemoryCopy.returnedAfterFadedBody,
          strength: 0.9,
          recencyWeight: 0.95,
          isUserCorrected: true,
          isFreshReturn: true,
        );
      }
      add(
        type: EvidenceAnchorType.corrected,
        summary: CorrectionMemoryCopy.bodyFor(correction.state),
        strength: 0.84,
        recencyWeight: 0.8,
        isUserCorrected: true,
      );
    }

    return candidates;
  }

  static List<EvidenceAnchor> _rankCandidates(List<_AnchorCandidate> candidates) {
    final deduped = <String, _AnchorCandidate>{};
    for (final candidate in candidates) {
      final key = candidate.safeSummary.toLowerCase();
      final existing = deduped[key];
      if (existing == null ||
          _scoreFor(existing) < _scoreFor(candidate)) {
        deduped[key] = candidate;
      }
    }

    final ranked = deduped.values.toList()
      ..sort((a, b) => _scoreFor(b).compareTo(_scoreFor(a)));

    return ranked
        .map(
          (candidate) => EvidenceAnchor(
            id: candidate.id,
            type: candidate.type,
            label: candidate.type.label,
            safeSummary: candidate.safeSummary,
            strength: candidate.strength,
            recencyWeight: candidate.recencyWeight,
            sourceCount: candidate.sourceCount,
            isUserCorrected: candidate.isUserCorrected,
            isFreshReturn: candidate.isFreshReturn,
            isSafeForDisplay: true,
          ),
        )
        .toList();
  }

  static double _scoreFor(_AnchorCandidate candidate) {
    final typeScore = _typePriority[candidate.type] ?? 0;
    return typeScore +
        candidate.recencyWeight * 10 +
        candidate.strength * 5 +
        (candidate.isUserCorrected ? 5 : 0) +
        (candidate.isFreshReturn ? 3 : 0);
  }

  static EvidenceAnchorType _typeForPhrase(String phrase) {
    final lower = phrase.toLowerCase();
    if (lower.contains('avoided')) return EvidenceAnchorType.avoided;
    if (lower.contains('helped') || lower.contains('helpful')) {
      return EvidenceAnchorType.helped;
    }
    if (lower.startsWith('change:')) return EvidenceAnchorType.change;
    return EvidenceAnchorType.repeat;
  }

  static double _recencyWeightForEntries(
    List<JournalEntry> entries,
    DateTime now,
  ) {
    if (entries.isEmpty) return 0.5;
    final latest = entries
        .map((entry) => entry.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final ageDays = now.difference(latest).inDays;
    if (ageDays <= recentWindowDays) return 1;
    if (ageDays <= recentWindowDays * 2) return 0.55;
    return 0.2;
  }

  static Set<String> _privateTextsFor(List<JournalEntry> entries) {
    final texts = <String>{};
    for (final entry in entries) {
      final resolution = resolveEntryDisplayText(entry);
      final text = resolution.text.trim().isNotEmpty
          ? resolution.text.trim()
          : entry.transcript.trim();
      if (text.isNotEmpty) texts.add(text.toLowerCase());
    }
    return texts;
  }

  static String? _sanitizeAnchor(
    String raw, {
    required Set<String> privateTexts,
    required Set<String> entryIds,
  }) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.length > maxAnchorLength) {
      final truncated =
          '${cleaned.substring(0, maxAnchorLength - 1).trim()}…';
      return _sanitizeAnchor(
        truncated,
        privateTexts: privateTexts,
        entryIds: entryIds,
      );
    }

    final lower = cleaned.toLowerCase();
    for (final id in entryIds) {
      if (id.isNotEmpty && lower.contains(id.toLowerCase())) return null;
    }
    if (RegExp(r'\bentry[_-]?id\b', caseSensitive: false).hasMatch(cleaned)) {
      return null;
    }
    if (lower.contains('transcript')) return null;

    for (final privateText in privateTexts) {
      if (privateText.length >= 24 && lower == privateText) return null;
    }

    return cleaned;
  }

  static EvidenceAnchor _fallbackAnchor() => EvidenceAnchor(
        id: 'anchor_fallback',
        type: EvidenceAnchorType.unknown,
        label: EvidenceAnchorType.unknown.label,
        safeSummary: EvidenceAnchorCopy.fallbackSummary,
        strength: 0.2,
        recencyWeight: 0,
        sourceCount: 0,
        isUserCorrected: false,
        isFreshReturn: false,
        isSafeForDisplay: false,
      );

  static bool _passesEvidenceQuality(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return true;
  }
}

class _AnchorCandidate {
  const _AnchorCandidate({
    required this.id,
    required this.type,
    required this.safeSummary,
    required this.strength,
    required this.recencyWeight,
    required this.sourceCount,
    required this.isUserCorrected,
    required this.isFreshReturn,
  });

  final String id;
  final EvidenceAnchorType type;
  final String safeSummary;
  final double strength;
  final double recencyWeight;
  final int sourceCount;
  final bool isUserCorrected;
  final bool isFreshReturn;
}

class ArchiveTimelineSpineRowAnchorHint {
  const ArchiveTimelineSpineRowAnchorHint({
    required this.rowId,
    required this.anchorType,
    required this.detail,
  });

  final ArchiveTimelineSpineRowId rowId;
  final EvidenceAnchorType anchorType;
  final String detail;
}
