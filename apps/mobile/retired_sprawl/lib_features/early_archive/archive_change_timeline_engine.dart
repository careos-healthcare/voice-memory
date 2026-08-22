import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/archive_change_timeline_copy.dart';
import 'package:archiveme_mobile/features/early_archive/archive_change_timeline_model.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_engine.dart';
import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the longitudinal evidence timeline from existing proof engines only.
abstract final class ArchiveChangeTimelineEngine {
  ArchiveChangeTimelineEngine._();

  static const _maxPhraseWords = 6;

  static ArchiveChangeTimeline? build({
    required List<JournalEntry> entries,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }

    if (!ArchiveEvidenceQualityGate.allowsProofTimeline(entries)) return null;

    final eligible = ArchiveEvidenceGuard.strongEntries(entries);
    if (eligible.length < 3) return null;

    final foundation = eligible.length >= 3 ? eligible.sublist(0, 3) : eligible;
    final repeatPhrase = _groundedPhrase(foundation);
    if (repeatPhrase == null) return null;

    final changeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
      records: returnChecks,
    );
    final latestChoice = RepeatReturnCheckTrendEngine.latestChoice(
      returnChecks,
    );
    final patternChanged = PatternChangedEngine.build(
      changeProof: changeProof,
      records: returnChecks,
      entries: entries,
    );
    final helpfulAction = HelpfulActionAppearedEngine.build(
      entries: entries,
      returnChecks: returnChecks,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );

    final items = <ArchiveChangeTimelineItem>[
      ArchiveChangeTimelineItem(
        kind: ArchiveChangeTimelineItemKind.firstSeen,
        label: ArchiveChangeTimelineCopy.firstSeenLabel,
        body: ArchiveChangeTimelineCopy.firstSeenBody,
        phrase: repeatPhrase,
      ),
      ArchiveChangeTimelineItem(
        kind: ArchiveChangeTimelineItemKind.repeated,
        label: ArchiveChangeTimelineCopy.repeatedLabel,
        body: ArchiveChangeTimelineCopy.repeatedBody,
        phrase: repeatPhrase,
      ),
      ..._returnCheckItems(latestChoice, eligible, repeatPhrase),
      if (patternChanged != null && patternChanged.usesPhraseEvidence)
        ArchiveChangeTimelineItem(
          kind: ArchiveChangeTimelineItemKind.changedThisTime,
          label: ArchiveChangeTimelineCopy.changedThisTimeLabel,
          body: ArchiveChangeTimelineCopy.changedThisTimeBody,
          phrase: patternChanged.thisTimePhrase,
        ),
      ?_helpfulItem(helpfulAction, eligible),
      const ArchiveChangeTimelineItem(
        kind: ArchiveChangeTimelineItemKind.stillWatching,
        label: ArchiveChangeTimelineCopy.stillWatchingLabel,
        body: ArchiveChangeTimelineCopy.stillWatchingBody,
      ),
    ];

    return ArchiveChangeTimeline(
      title: ArchiveChangeTimelineCopy.title,
      subtitle: ArchiveChangeTimelineCopy.subtitle,
      items: items,
    );
  }

  static List<ArchiveChangeTimelineItem> _returnCheckItems(
    RepeatReturnCheckChoice? latestChoice,
    List<JournalEntry> eligible,
    String foundationPhrase,
  ) {
    if (latestChoice == null ||
        latestChoice == RepeatReturnCheckChoice.changed) {
      return const [];
    }

    final phrase = _latestGroundedPhrase(eligible) ?? foundationPhrase;
    if (!_isGroundedPhrase(phrase, eligible)) return const [];

    return switch (latestChoice) {
      RepeatReturnCheckChoice.softer => [
        ArchiveChangeTimelineItem(
          kind: ArchiveChangeTimelineItemKind.lookedSofter,
          label: ArchiveChangeTimelineCopy.lookedSofterLabel,
          body: ArchiveChangeTimelineCopy.lookedSofterBody,
          phrase: phrase,
        ),
      ],
      RepeatReturnCheckChoice.stronger => [
        ArchiveChangeTimelineItem(
          kind: ArchiveChangeTimelineItemKind.lookedStronger,
          label: ArchiveChangeTimelineCopy.lookedStrongerLabel,
          body: ArchiveChangeTimelineCopy.lookedStrongerBody,
          phrase: phrase,
        ),
      ],
      RepeatReturnCheckChoice.same => [
        ArchiveChangeTimelineItem(
          kind: ArchiveChangeTimelineItemKind.aboutTheSame,
          label: ArchiveChangeTimelineCopy.aboutTheSameLabel,
          body: ArchiveChangeTimelineCopy.aboutTheSameBody,
          phrase: phrase,
        ),
      ],
      RepeatReturnCheckChoice.changed => const [],
    };
  }

  static ArchiveChangeTimelineItem? _helpfulItem(
    HelpfulActionAppeared? helpfulAction,
    List<JournalEntry> entries,
  ) {
    final phrase = helpfulAction?.actionPhrase;
    if (helpfulAction == null ||
        !helpfulAction.usesActionPhrase ||
        phrase == null ||
        !_isGroundedPhrase(phrase, entries)) {
      return null;
    }
    return ArchiveChangeTimelineItem(
      kind: ArchiveChangeTimelineItemKind.helpfulActionAppeared,
      label: ArchiveChangeTimelineCopy.helpfulActionAppearedLabel,
      body: ArchiveChangeTimelineCopy.helpfulActionAppearedBody,
      phrase: phrase,
    );
  }

  static String? _groundedPhrase(List<JournalEntry> entries) {
    final shared = ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(
      entries,
    );
    if (shared != null && _isGroundedPhrase(shared, entries)) return shared;

    for (final phrase in ConfirmedRepeatEvidencePhraseEngine.extract(
      entries,
    ).phrases) {
      if (_isGroundedPhrase(phrase, entries)) return phrase;
    }
    return null;
  }

  static String? _latestGroundedPhrase(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    final phrase =
        ConfirmedRepeatEvidencePhraseEngine.singleEntryConcretePhrase(
          entries.last,
        );
    if (phrase == null || !_isGroundedPhrase(phrase, entries)) return null;
    return phrase;
  }

  static bool _isGroundedPhrase(String phrase, List<JournalEntry> entries) {
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return false;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return false;
    }
    if (entries.isNotEmpty &&
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: phrase,
          entries: entries,
        )) {
      return false;
    }
    final words = phrase.trim().split(RegExp(r'\s+'));
    return words.isNotEmpty && words.length <= _maxPhraseWords;
  }
}