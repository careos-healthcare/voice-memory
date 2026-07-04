import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../record_capture_modes/record_capture_mode_engine.dart';
import '../repeat_return_check/repeat_return_check_gates.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import '../weekly_review/weekly_archive_review_copy.dart';
import '../weekly_review/weekly_archive_review_model.dart';
import 'what_changed_v2_copy.dart';
import 'what_changed_v2_model.dart';
import 'what_changed_v2_store.dart';

/// User-reported change markers — upgrades post-save return check flow.
abstract final class WhatChangedV2Engine {
  WhatChangedV2Engine._();

  static const minEntryCount = 4;

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
    if (WhatChangedV2Store.cached
        .any((record) => record.entryId == latestEntryId)) {
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
      prompt != null;

  static WeeklyArchiveReviewSection? weeklyReviewSection({
    required List<JournalEntry> entries,
  }) {
    final ids = entries.map((entry) => entry.id).toSet();
    final marker = WhatChangedV2Store.cached
        .where((record) => ids.contains(record.entryId))
        .where((record) => record.option != WhatChangedV2Option.somethingHelped)
        .firstOrNull;
    if (marker == null) return null;

    return WeeklyArchiveReviewSection(
      label: WeeklyArchiveReviewCopy.whatChangedLabel,
      body: WhatChangedV2Copy.weeklyReviewLine(marker.option),
      isSupported: true,
    );
  }

  static bool _allowsPrompt(List<JournalEntry> entries) {
    if (entries.length < minEntryCount) return false;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return false;
    }
    if (!RepeatReturnCheckGates.hasRelatedRepeatSave(entries)) return false;
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final foundation = eligible.length >= 3
        ? eligible.sublist(0, 3)
        : eligible;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(foundation);
    if (!evidence.isStrong) return false;

    final latest = eligible.lastOrNull ?? entries.last;
    final text = ComparableEvidenceText.userText(latest);
    if (text.trim().isEmpty) return false;
    if (RecordCaptureModeEngine.isQuietDayText(text)) return false;

    return true;
  }
}
