import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:archiveme_mobile/features/retention/first_week_progress_copy.dart';
import 'package:archiveme_mobile/features/retention/first_week_progress_model.dart';
import 'package:archiveme_mobile/features/retention/return_tomorrow_cue_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Visibility gates for first-week progress.
abstract final class FirstWeekProgressGates {
  FirstWeekProgressGates._();

  static const maxWeekDays = 7;

  static bool archiveAllowsProgress(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;
    return true;
  }

  static int? weekDayNumber({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    final clock = now ?? DateTime.now();
    final first = eligible
        .map((e) => e.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final firstDay = DateTime(first.year, first.month, first.day);
    final today = DateTime(clock.year, clock.month, clock.day);
    final dayNumber = today.difference(firstDay).inDays + 1;
    if (dayNumber < 1 || dayNumber > maxWeekDays) return null;
    return dayNumber;
  }

  static bool shouldShowReady({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool showReturnDayFlow, required bool showReturnTomorrowCue, FirstWeekProgress? progress,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      progress != null &&
      !showReturnDayFlow &&
      !showReturnTomorrowCue;

  static bool shouldShowPostSave({
    required bool isPostSaveDone,
    required bool isDegradedPostSave,
    required bool showReturnTomorrowCue, FirstWeekProgress? progress,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      progress != null &&
      !showReturnTomorrowCue;
}

/// Builds first-week progress from journal evidence — local only.
abstract final class FirstWeekProgressEngine {
  FirstWeekProgressEngine._();

  static FirstWeekProgress? buildReady({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (!FirstWeekProgressGates.archiveAllowsProgress(entries)) return null;

    final weekDay = FirstWeekProgressGates.weekDayNumber(
      entries: entries,
      now: now,
    );
    if (weekDay == null) return null;

    return _buildForWeekDay(
      entries: entries,
      weekDay: weekDay,
      firstProofUnlocked: false,
      preferDay2OnReturn: true,
      now: now,
    );
  }

  static FirstWeekProgress? buildPostSave({
    required List<JournalEntry> entries,
    required bool firstProofUnlocked,
    DateTime? now,
  }) {
    if (!FirstWeekProgressGates.archiveAllowsProgress(entries)) return null;

    final weekDay = FirstWeekProgressGates.weekDayNumber(
      entries: entries,
      now: now,
    );
    if (weekDay == null) return null;

    return _buildForWeekDay(
      entries: entries,
      weekDay: weekDay,
      firstProofUnlocked: firstProofUnlocked,
      preferDay2OnReturn: false,
      now: now,
    );
  }

  static FirstWeekProgress? _buildForWeekDay({
    required List<JournalEntry> entries,
    required int weekDay,
    required bool firstProofUnlocked,
    required bool preferDay2OnReturn,
    DateTime? now,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final hasFirstProof =
        firstProofUnlocked ||
        (eligible.length >= 3 &&
            FirstProofMomentEngine.build(entries: entries) != null);

    if (hasFirstProof) {
      return FirstWeekProgress(
        state: FirstWeekProgressState.firstProof,
        title: FirstWeekProgressCopy.firstProofTitle,
        body: FirstWeekProgressCopy.firstProofBody,
        weekDay: weekDay,
      );
    }

    // One entry on day 1 — skip "Day 1 of 7" program framing; first-save card
    // already explains when to return.
    if (weekDay == 1 && eligible.length > 1) {
      return const FirstWeekProgress(
        state: FirstWeekProgressState.day1,
        title: FirstWeekProgressCopy.day1Title,
        body: FirstWeekProgressCopy.day1Body,
        weekDay: 1,
      );
    }

    if (weekDay == 2) {
      if (preferDay2OnReturn &&
          !ReturnTomorrowCueGates.isNextDayReturn(entries: entries, now: now)) {
        return null;
      }
      return const FirstWeekProgress(
        state: FirstWeekProgressState.day2,
        title: FirstWeekProgressCopy.day2Title,
        body: FirstWeekProgressCopy.day2Body,
        weekDay: 2,
      );
    }

    if (weekDay >= 3) {
      return FirstWeekProgress(
        state: FirstWeekProgressState.day3to7,
        title: FirstWeekProgressCopy.dayNTitle(weekDay),
        body: FirstWeekProgressCopy.day3to7Body,
        weekDay: weekDay,
      );
    }

    return null;
  }
}