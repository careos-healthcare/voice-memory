import 'package:archiveme_mobile/features/archive_value/archive_value_progress.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

enum ArchiveMovementKind {
  confidenceChanged,
  evidenceIncreased,
  statusChanged,
  newLifeArea,
  contradictionDetected,
  costEvidenceDetected,
  underReview,
}

class ArchiveMovementUpdate {
  const ArchiveMovementUpdate({
    required this.kind,
    required this.eyebrow,
    required this.headline,
    required this.reason,
    this.detailLine,
  });

  final ArchiveMovementKind kind;
  final String eyebrow;
  final String headline;
  final String reason;
  final String? detailLine;
}

class ArchiveMovementEngine {
  static const eyebrow = 'Archive update';

  static String _ladderLabel(ArchiveValueStage stage) {
    switch (stage) {
      case ArchiveValueStage.oneDataPoint:
        return 'One data point';
      case ArchiveValueStage.possibleRepeat:
        return 'Possible repeat';
      case ArchiveValueStage.patternForming:
        return 'Evidence growing';
      case ArchiveValueStage.theoryUnderReview:
        return 'Theory under review';
      case ArchiveValueStage.patternReviewUnlocked:
        return 'First working theory unlocked';
    }
  }

  static List<JournalEntry> _eligible(List<JournalEntry> entries) {
    return entries.where((e) => e.transcript.trim().isNotEmpty).toList();
  }

  static ArchiveMovementUpdate build(
    List<JournalEntry> entriesAfter, {
    String? newEntryId,
  }) {
    final after = _eligible(entriesAfter);
    final before = newEntryId != null
        ? after.where((e) => e.id != newEntryId).toList()
        : after.length > 1
        ? after.sublist(0, after.length - 1)
        : <JournalEntry>[];

    final snapBefore = ArchiveValueProgress.build(before);
    final snapAfter = ArchiveValueProgress.build(after);

    if (snapAfter.reflectionCount > snapBefore.reflectionCount) {
      final beforeN = snapBefore.reflectionCount;
      final afterN = snapAfter.reflectionCount;
      return ArchiveMovementUpdate(
        kind: ArchiveMovementKind.evidenceIncreased,
        eyebrow: eyebrow,
        headline: 'New experiences supported this view.',
        detailLine: '$beforeN → $afterN supporting reflections',
        reason: afterN >= 3
            ? 'Your archive is becoming harder to fool.'
            : 'New experiences supported this view.',
      );
    }

    if (snapBefore.stage != snapAfter.stage) {
      return ArchiveMovementUpdate(
        kind: ArchiveMovementKind.statusChanged,
        eyebrow: eyebrow,
        headline: 'Status changed',
        detailLine:
            '${_ladderLabel(snapBefore.stage)} → ${_ladderLabel(snapAfter.stage)}',
        reason: 'Your archive is still evaluating this theory.',
      );
    }

    if (snapAfter.reflectionCount >= 1) {
      return ArchiveMovementUpdate(
        kind: ArchiveMovementKind.underReview,
        eyebrow: eyebrow,
        headline: 'No major change yet',
        reason: 'Your archive is still evaluating this theory.',
        detailLine: snapAfter.valueCopy,
      );
    }

    return const ArchiveMovementUpdate(
      kind: ArchiveMovementKind.underReview,
      eyebrow: eyebrow,
      headline: 'No major change yet',
      reason: 'Your archive is waiting for a first reflection.',
    );
  }
}