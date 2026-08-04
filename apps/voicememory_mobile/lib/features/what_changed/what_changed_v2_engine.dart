import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../explainable_conclusion/auditable_personal_change_engine.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import '../weekly_review/weekly_archive_review_copy.dart';
import '../weekly_review/weekly_archive_review_model.dart';
import 'what_changed_v2_copy.dart';
import 'what_changed_v2_model.dart';
import 'what_changed_v2_store.dart';

/// User-reported change markers — last time vs this time comparison.
abstract final class WhatChangedV2Engine {
  WhatChangedV2Engine._();

  static const minEntryCount = 2;
  static const _maxSnippetChars = 72;
  static const _minSnippetChars = 12;

  static const promptOptions = [
    WhatChangedV2Option.stronger,
    WhatChangedV2Option.softer,
    WhatChangedV2Option.same,
    WhatChangedV2Option.differentResponse,
    WhatChangedV2Option.somethingHelped,
  ];

  static WhatChangedV2Prompt? buildPrompt({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    if (!_allowsPrompt(entries)) return null;

    final latestEntryId = RepeatReturnCheckStore.latestSavedEntryId(entries);
    if (WhatChangedV2Store.cached.any(
      (record) => record.entryId == latestEntryId,
    )) {
      return null;
    }

    final existing = returnChecks
        .where((record) => record.entryId == latestEntryId)
        .firstOrNull;
    if (existing?.choice != null) return null;

    return WhatChangedV2Prompt(
      entryId: latestEntryId,
      entryCount: entries.length,
      hasConfirmedRepeat: true,
      options: promptOptions,
      comparison: buildComparison(entries: entries),
    );
  }

  /// Post-save surface — unanswered prompt or answered comparison payoff.
  static WhatChangedV2Prompt? buildPostSaveDisplay({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final unanswered = buildPrompt(
      entries: entries,
      returnChecks: returnChecks,
    );
    if (unanswered != null) return unanswered;

    final payoff = buildAnsweredPayoff(entries: entries);
    if (payoff == null) return null;
    if (payoff.option == WhatChangedV2Option.somethingHelped) return null;
    if (!_hasGroundedRepeatContext(entries)) return null;

    final latestEntryId = RepeatReturnCheckStore.latestSavedEntryId(entries);
    return WhatChangedV2Prompt(
      entryId: latestEntryId,
      entryCount: entries.length,
      hasConfirmedRepeat: true,
      options: promptOptions,
      comparison: payoff.comparison,
    );
  }

  static WhatChangedV2Comparison? buildComparison({
    required List<JournalEntry> entries,
  }) {
    if (!_hasGroundedRepeatContext(entries)) {
      return null;
    }
    return _comparisonFromEligible(entries);
  }

  static WhatChangedV2AnsweredPayoff? buildAnsweredPayoff({
    required List<JournalEntry> entries,
  }) {
    final ids = entries.map((entry) => entry.id).toSet();
    final marker = WhatChangedV2Store.cached
        .where((record) => ids.contains(record.entryId))
        .firstOrNull;
    if (marker == null) return null;

    final comparison = buildComparison(entries: entries);
    if (comparison == null) return null;

    return WhatChangedV2AnsweredPayoff(
      option: marker.option,
      payoffLine: WhatChangedV2Copy.payoffMessage(marker.option),
      comparison: comparison,
    );
  }

  static bool shouldShowOnPostSave({
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    required bool showFirstProofMoment,
    WhatChangedV2Prompt? prompt,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      !showFirstProofMoment &&
      prompt != null &&
      prompt.hasComparison;

  static bool shouldShowPostSaveDisplay({
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    required bool showFirstProofMoment,
    WhatChangedV2Prompt? display,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      !showFirstProofMoment &&
      display != null &&
      display.hasComparison;

  static WeeklyArchiveReviewSection? weeklyReviewSection({
    required List<JournalEntry> entries,
  }) {
    final payoff = buildAnsweredPayoff(entries: entries);
    if (payoff == null) return null;

    return WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatChangedLabel,
      body: payoff.payoffLine,
      isSupported: true,
    );
  }

  static bool _hasGroundedRepeatContext(List<JournalEntry> entries) {
    if (entries.length < minEntryCount) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return _comparisonFromEligible(entries) != null;
  }

  static bool _allowsPrompt(List<JournalEntry> entries) {
    if (entries.length < minEntryCount) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final latest = eligible.lastOrNull ?? entries.last;
    final text = ComparableEvidenceText.userText(latest);
    if (text.trim().isEmpty) return false;
    if (RecordCaptureModeEngine.isQuietDayText(text)) return false;

    return _comparisonFromEligible(entries) != null;
  }

  static WhatChangedV2Comparison? _comparisonFromEligible(
    List<JournalEntry> entries,
  ) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (eligible.length < 2) return null;

    final prior = eligible[eligible.length - 2];
    final latest = eligible.last;
    if (!AuditablePersonalChangeEngine.areRelated(prior, latest)) return null;

    final thenSnippet = _snippetForEntry(prior, const []);
    final nowSnippet = _snippetForEntry(latest, const []);
    if (thenSnippet == null || nowSnippet == null) return null;
    if (thenSnippet.toLowerCase().trim() == nowSnippet.toLowerCase().trim()) {
      return null;
    }

    return WhatChangedV2Comparison(
      thenSnippet: thenSnippet,
      nowSnippet: nowSnippet,
    );
  }

  static String? _snippetForEntry(
    JournalEntry entry,
    List<String> groundedPhrases,
  ) {
    final text = ComparableEvidenceText.userText(entry);
    if (text.length < _minSnippetChars) return null;

    for (final phrase in groundedPhrases) {
      final normalized = phrase.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final index = text.toLowerCase().indexOf(normalized);
      if (index < 0) continue;

      final start = index > 24 ? index - 24 : 0;
      final end = (index + normalized.length + 32).clamp(0, text.length);
      final slice = text.substring(start, end).trim();
      if (slice.length >= _minSnippetChars) return _trimSnippet(slice);
    }

    if (text.length >= _minSnippetChars) return _trimSnippet(text);
    return null;
  }

  static String _trimSnippet(String snippet) {
    final cleaned = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _maxSnippetChars) return cleaned;
    return '${cleaned.substring(0, _maxSnippetChars - 1).trim()}…';
  }
}
