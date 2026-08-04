import '../../models/journal_entry.dart';
import '../../security/user_content_safety.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/daily_return_reason_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/positive_pattern_engine.dart';
import '../early_archive/positive_pattern_models.dart';
import '../helped_tracking/helped_tracking_engine.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../timeline/timeline_entry_display.dart';
import '../quiet_signal/quiet_signal_engine.dart';
import '../weekly_review/weekly_archive_review_copy.dart';
import '../weekly_review/weekly_archive_review_engine.dart';
import '../what_changed/what_changed_v2_copy.dart';
import '../what_changed/what_changed_v2_engine.dart';
import '../what_changed/what_changed_v2_model.dart';
import '../what_changed/what_changed_v2_store.dart';
import '../early_archive/private_archive_report_model.dart';
import 'private_report_copy.dart';

/// Builds the private archive report from existing proof engines only.
abstract final class PrivateReportBuilder {
  PrivateReportBuilder._();

  static const _maxPhraseWords = 6;
  static const _maxEvidenceSnippets = 3;
  static const _maxSnippetChars = 52;

  static PrivateArchiveReport? build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
    bool isRecording = false,
    bool isPostSave = false,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return null;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return null;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return null;
    }
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }
    if (!ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return null;

    final eligible = ArchiveEvidenceGuard.strongEntries(entries);
    if (eligible.length < 3) return null;

    final reviewEntries = WeeklyArchiveReviewEngine.shouldShow(entries: entries)
        ? _reviewEntries(entries)
        : eligible;
    final changeProof = RepeatReturnCheckEngine.changeProofForReady(
      entryCount: entries.length,
      viewingConfirmedRepeat: viewingConfirmedRepeatOrTimeline,
      isRecording: isRecording,
      isPostSave: isPostSave,
      records: returnChecks,
    );
    final positivePattern = PositivePatternEngine.build(entries: entries);
    final repeatPhrase = _groundedPhrase(reviewEntries);
    if (repeatPhrase == null) return null;

    final repeatCount = _countMomentsWithPhrase(reviewEntries, repeatPhrase);
    final contentSections = [
      _whatRepeatedSection(repeatPhrase, repeatCount),
      _whatChangedSection(
        entries: reviewEntries,
        sourceEntries: entries,
        changeProof: changeProof,
        returnChecks: returnChecks,
      ),
      _whatHelpedSection(
        entries: entries,
        returnChecks: returnChecks,
        positivePattern: positivePattern,
      ),
    ];
    final sections = [
      ...contentSections,
      _evidenceSection(
        entries: reviewEntries,
        repeatPhrase: repeatPhrase,
        sections: contentSections,
      ),
      _whatToWatchNextSection(
        entries: entries,
        changeProof: changeProof,
        triggerCapturedMilestone: triggerCapturedMilestone,
        helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
        returnChecks: returnChecks,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      ),
    ];

    final report = PrivateArchiveReport(
      title: PrivateReportCopy.title,
      intro: PrivateReportCopy.subtitle,
      sections: sections,
    );

    if (!report.hasContent) return null;
    return report;
  }

  static List<JournalEntry> _reviewEntries(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return entries;

    if (eligible.length >= 3) {
      return eligible.sublist(eligible.length - 3);
    }
    return eligible;
  }

  static PrivateArchiveReportSection _whatRepeatedSection(
    String phrase,
    int count,
  ) {
    final displayPhrase = PatternNameEngine.displayLabelForGroundedPhrase(
      phrase,
    );
    return PrivateArchiveReportSection(
      heading: PrivateReportCopy.whatRepeatedHeading,
      lines: [PrivateReportCopy.whatRepeatedBody(displayPhrase, count)],
    );
  }

  static PrivateArchiveReportSection _whatChangedSection({
    required List<JournalEntry> entries,
    required List<JournalEntry> sourceEntries,
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) {
    final v2 = WhatChangedV2Engine.weeklyReviewSection(entries: sourceEntries);
    if (v2 != null && v2.isSupported) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatChangedHeading,
        lines: [v2.body.trim()],
      );
    }

    final entryIds = sourceEntries.map((entry) => entry.id).toSet();
    final changeMarker = WhatChangedV2Store.cached
        .where((record) => entryIds.contains(record.entryId))
        .firstOrNull;
    if (changeMarker != null &&
        changeMarker.option != WhatChangedV2Option.somethingHelped) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatChangedHeading,
        lines: [WhatChangedV2Copy.payoffMessage(changeMarker.option)],
      );
    }

    final changeNotice = EarlyFirstSignalEngine.buildChangeNotice(
      entries: entries,
    );
    if (changeNotice != null && changeNotice.body.trim().isNotEmpty) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatChangedHeading,
        lines: [changeNotice.body.trim()],
      );
    }

    if (changeProof != null && changeProof.body.trim().isNotEmpty) {
      final choice = changeProof.latestChoice;
      final line = switch (choice) {
        RepeatReturnCheckChoice.softer =>
          'One later entry sounded softer than before.',
        RepeatReturnCheckChoice.stronger =>
          'One later entry sounded more aware of the pressure.',
        RepeatReturnCheckChoice.same =>
          'Later entries stayed about the same this week.',
        RepeatReturnCheckChoice.changed =>
          'One later entry sounded different from earlier moments.',
      };
      if (choice != RepeatReturnCheckChoice.changed) {
        return PrivateArchiveReportSection(
          heading: PrivateReportCopy.whatChangedHeading,
          lines: [line],
        );
      }
    }

    final choice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    if (choice == RepeatReturnCheckChoice.softer) {
      return const PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatChangedHeading,
        lines: ['One later entry sounded more aware of checking capacity.'],
      );
    }

    return _fallbackSection(PrivateReportCopy.whatChangedHeading);
  }

  static PrivateArchiveReportSection _whatHelpedSection({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    PositivePatternResult? positivePattern,
  }) {
    final fromMarkers = HelpedTrackingEngine.weeklyReviewSection(
      entries: entries,
      returnChecks: returnChecks,
      positivePattern: positivePattern,
    );
    if (fromMarkers != null && fromMarkers.isSupported) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatHelpedHeading,
        lines: [fromMarkers.body.trim()],
      );
    }

    return _fallbackSection(PrivateReportCopy.whatHelpedHeading);
  }

  static PrivateArchiveReportSection _whatToWatchNextSection({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    final quietSignal = QuietSignalEngine.build(entries: entries);
    if (quietSignal != null &&
        quietSignal.privateReportLine != null &&
        quietSignal.privateReportLine!.trim().isNotEmpty) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatToWatchNextHeading,
        lines: [quietSignal.privateReportLine!.trim()],
      );
    }

    final dailyReason = DailyReturnReasonEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    final prompt = dailyReason?.prompt.trim();
    if (prompt != null && prompt.isNotEmpty) {
      return PrivateArchiveReportSection(
        heading: PrivateReportCopy.whatToWatchNextHeading,
        lines: [prompt],
      );
    }

    return const PrivateArchiveReportSection(
      heading: PrivateReportCopy.whatToWatchNextHeading,
      lines: [WeeklyArchiveReviewCopy.watchBeforeAgree],
    );
  }

  static PrivateArchiveReportSection _evidenceSection({
    required List<JournalEntry> entries,
    required String repeatPhrase,
    required List<PrivateArchiveReportSection> sections,
  }) {
    final phrases = <String>{
      PatternNameEngine.displayLabelForGroundedPhrase(repeatPhrase),
      repeatPhrase,
    };

    for (final section in sections) {
      for (final line in section.lines) {
        for (final match in RegExp(r'"([^"]+)"').allMatches(line)) {
          final phrase = match.group(1)?.trim();
          if (phrase != null && phrase.isNotEmpty) phrases.add(phrase);
        }
      }
    }

    final bullets = <String>[];
    for (final phrase in phrases) {
      if (_isGroundedPhrase(phrase, entries)) {
        bullets.add('"$phrase"');
      }
    }

    for (final entry in entries.reversed) {
      if (bullets.length >= _maxEvidenceSnippets + phrases.length) break;
      final text = _entryText(entry);
      if (text.isEmpty) continue;
      final normalized = text.toLowerCase();
      final matchesPhrase = phrases.any(
        (phrase) => normalized.contains(phrase.toLowerCase()),
      );
      if (!matchesPhrase) continue;

      final snippet = UserContentSafety.safeSnippet(
        text,
        maxChars: _maxSnippetChars,
      );
      if (snippet.trim().isEmpty) continue;
      if (bullets.any((bullet) => bullet.contains(snippet))) continue;

      bullets.add(
        PrivateReportCopy.evidenceSnippet(
          snippet,
          relativeDate: _relativeDateLabel(entry.createdAt),
        ),
      );
    }

    if (bullets.isEmpty) {
      return _fallbackSection(PrivateReportCopy.evidenceHeading);
    }

    return PrivateArchiveReportSection(
      heading: PrivateReportCopy.evidenceHeading,
      bullets: bullets.take(_maxEvidenceSnippets).toList(),
    );
  }

  static PrivateArchiveReportSection _fallbackSection(String heading) =>
      PrivateArchiveReportSection(
        heading: heading,
        lines: const [PrivateReportCopy.sectionFallback],
      );

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

  static int _countMomentsWithPhrase(
    List<JournalEntry> entries,
    String phrase,
  ) {
    final normalized = phrase.toLowerCase().trim();
    if (normalized.isEmpty) return 0;
    return entries
        .where((entry) => _entryText(entry).toLowerCase().contains(normalized))
        .length;
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

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String? _relativeDateLabel(DateTime createdAt) {
    final now = DateTime.now();
    final local = createdAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(local.year, local.month, local.day);
    final delta = today.difference(entryDay).inDays;
    return switch (delta) {
      0 => 'Today',
      1 => 'Yesterday',
      < 7 => '${delta}d ago',
      _ => null,
    };
  }
}
