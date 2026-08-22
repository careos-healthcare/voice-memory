import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_demo_preview_copy.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_demo_preview_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_engine.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Maps existing Daily Mirror output to a cold-start demo preview.
class ArchiveDemoPreviewResolver {
  const ArchiveDemoPreviewResolver();

  ArchiveDemoPreview resolve(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final count = eligible.length;
    if (count == 0 || count >= 3) return ArchiveDemoPreview.none;

    if (count == 1) {
      return const ArchiveDemoPreview(
        shouldShow: true,
        patternFirstSeen: ArchiveDemoPreviewCopy.oneEntryPatternHint,
        repeatWouldBe: ArchiveDemoPreviewCopy.oneEntryRepeatHint,
        softeningWouldBe: ArchiveDemoPreviewCopy.oneEntrySofteningHint,
        recordNext: ArchiveDemoPreviewCopy.oneEntryRecordNextHint,
      );
    }

    final mirror = const DailyMirrorEngine().build(eligible);
    if (mirror.stage == DailyMirrorStage.possibleLoop) {
      return ArchiveDemoPreview(
        shouldShow: true,
        patternFirstSeen: mirror.heroBody,
        repeatWouldBe: ArchiveDemoPreviewCopy.twoEntryPossibleLoopRepeatHint,
        softeningWouldBe:
            mirror.nextQuestion ?? ArchiveDemoPreviewCopy.twoEntrySofteningHint,
        recordNext: mirror.primaryCta.isNotEmpty
            ? mirror.primaryCta
            : ArchiveDemoPreviewCopy.twoEntryRecordNextHint,
      );
    }

    return const ArchiveDemoPreview(
      shouldShow: true,
      patternFirstSeen: ArchiveDemoPreviewCopy.twoEntryNoRepeatHint,
      repeatWouldBe: ArchiveDemoPreviewCopy.twoEntryRepeatHint,
      softeningWouldBe: ArchiveDemoPreviewCopy.twoEntrySofteningHint,
      recordNext: ArchiveDemoPreviewCopy.twoEntryRecordNextHint,
    );
  }
}