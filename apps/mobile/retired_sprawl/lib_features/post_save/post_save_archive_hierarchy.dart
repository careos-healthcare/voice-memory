import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_engine.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/record/first_proof_moment_card.dart' show FirstProofMomentCard;

/// Which single archive result to show below the heard excerpt on Record post-save.
enum PostSavePrimaryArchiveKind {
  lowSignal,
  quietDay,
  discovery,
  beliefUpdate,
  savedPrivately,
  firstEntryFootnote,

  /// Third related save — heard excerpt only; [FirstProofMomentCard] owns payoff.
  firstProofUnlocked,
}

/// Picks one primary archive result for the Record post-save stack.
class PostSaveArchiveHierarchy {
  const PostSaveArchiveHierarchy({
    required this.kind,
    this.mirror,
    this.beliefUpdatePayoff,
  });

  final PostSavePrimaryArchiveKind kind;
  final DailyMirrorResult? mirror;
  final BeliefUpdatePayoff? beliefUpdatePayoff;

  bool get showBeliefUpdateCard =>
      kind == PostSavePrimaryArchiveKind.beliefUpdate;

  bool get showMomentQualityFeedback =>
      kind != PostSavePrimaryArchiveKind.firstProofUnlocked;

  bool get showFocusedActionsBar =>
      kind != PostSavePrimaryArchiveKind.firstProofUnlocked;

  static PostSaveArchiveHierarchy resolve({
    required List<JournalEntry> entries,
    required bool suppressLatestSaveArchiveInsight,
    BeliefUpdatePayoff? beliefUpdatePayoff,
    DailyMirrorResult? mirror,
    bool firstProofUnlocked = false,
  }) {
    if (entries.isEmpty) {
      return const PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.firstEntryFootnote,
      );
    }

    if (suppressLatestSaveArchiveInsight) {
      final newest = entries.first;
      if (RecordCaptureModeEngine.entryIsQuietDay(newest)) {
        return const PostSaveArchiveHierarchy(
          kind: PostSavePrimaryArchiveKind.quietDay,
        );
      }
      return const PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.lowSignal,
      );
    }

    final resolvedMirror = mirror ?? const DailyMirrorEngine().build(entries);

    if (firstProofUnlocked) {
      return PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.firstProofUnlocked,
        mirror: resolvedMirror,
      );
    }

    if (_hasDiscovery(resolvedMirror)) {
      return PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.discovery,
        mirror: resolvedMirror,
      );
    }

    if (beliefUpdatePayoff != null) {
      return PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.beliefUpdate,
        mirror: resolvedMirror,
        beliefUpdatePayoff: beliefUpdatePayoff,
      );
    }

    if (_isFirstSavedEntry(entries) && _hasHeardText(entries.first)) {
      return PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.firstEntryFootnote,
        mirror: resolvedMirror,
      );
    }

    if (!resolvedMirror.hasGroundedEvidence &&
        !resolvedMirror.hasChange &&
        _hasHeardText(entries.first)) {
      return PostSaveArchiveHierarchy(
        kind: PostSavePrimaryArchiveKind.savedPrivately,
        mirror: resolvedMirror,
      );
    }

    return PostSaveArchiveHierarchy(
      kind: PostSavePrimaryArchiveKind.firstEntryFootnote,
      mirror: resolvedMirror,
    );
  }

  static bool _hasDiscovery(DailyMirrorResult mirror) {
    if (mirror.stage == DailyMirrorStage.possibleLoop &&
        mirror.hasGroundedEvidence) {
      return true;
    }
    if (mirror.stage == DailyMirrorStage.whatChanged && mirror.hasChange) {
      return true;
    }
    return false;
  }

  static bool _isFirstSavedEntry(List<JournalEntry> entries) =>
      entries.length == 1;

  static bool _hasHeardText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.trim().isNotEmpty) return true;
    return entry.transcript.trim().isNotEmpty;
  }
}