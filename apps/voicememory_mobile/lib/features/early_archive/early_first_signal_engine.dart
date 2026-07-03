import '../../models/journal_entry.dart';
import '../activation/first_three_journey_engine.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../retention/second_session_signal_engine.dart';
import '../timeline/timeline_entry_display.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_archive_insight_quality_copy.dart';
import 'early_archive_insight_quality_engine.dart';
import 'early_first_signal_copy.dart';

enum EarlyFirstSignalKind {
  oneEntryReceipt,
  twoEntryNoPattern,
  twoEntryFirstSignal,
  threeEntryConfirmedRepeat,
}

/// One line of user-visible evidence on the confirmed-repeat card.
class EarlyFirstSignalEvidenceRow {
  const EarlyFirstSignalEvidenceRow({
    required this.timestampLabel,
    required this.snippet,
  });

  final String timestampLabel;
  final String snippet;
}

/// Lightweight next-observation prompt after a confirmed 3-entry repeat.
class EarlyFirstSignalReturnPrompt {
  const EarlyFirstSignalReturnPrompt({
    required this.title,
    required this.body,
    required this.cta,
    required this.guidedRecordPrompt,
  });

  final String title;
  final String body;
  final String cta;
  final String guidedRecordPrompt;
}

/// User-facing early archive card — deterministic, no invented patterns.
class EarlyFirstSignalModel {
  const EarlyFirstSignalModel({
    required this.kind,
    required this.title,
    required this.lines,
    required this.primaryCta,
    this.evidenceHeading,
    this.evidenceRows = const [],
    this.evidencePhrases = const [],
    this.evidenceSupportLine,
    this.secondaryCta,
    this.returnPrompt,
  });

  final EarlyFirstSignalKind kind;
  final String title;
  final List<String> lines;
  final String primaryCta;
  final String? evidenceHeading;
  final List<EarlyFirstSignalEvidenceRow> evidenceRows;
  final List<String> evidencePhrases;
  final String? evidenceSupportLine;
  final String? secondaryCta;
  final EarlyFirstSignalReturnPrompt? returnPrompt;

  bool get showsPatternLanguage =>
      kind == EarlyFirstSignalKind.twoEntryFirstSignal ||
      kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat;

  bool get showsConfirmedRepeat =>
      kind == EarlyFirstSignalKind.threeEntryConfirmedRepeat;
}

/// Post-save payoff after capturing the trigger from the return prompt.
class ConfirmedRepeatTriggerPayoff {
  const ConfirmedRepeatTriggerPayoff({
    required this.title,
    required this.body,
    required this.evidenceLines,
    required this.primaryCta,
    required this.secondaryCta,
  });

  final String title;
  final String body;
  final List<String> evidenceLines;
  final String primaryCta;
  final String secondaryCta;
}

/// Grounded change notice when a later repeat entry sounds softer.
class ConfirmedRepeatChangeNotice {
  const ConfirmedRepeatChangeNotice({
    required this.title,
    required this.body,
    required this.evidenceLines,
    required this.primaryCta,
    required this.secondaryCta,
    required this.guidedRecordPrompt,
  });

  final String title;
  final String body;
  final List<String> evidenceLines;
  final String primaryCta;
  final String secondaryCta;
  final String guidedRecordPrompt;
}

/// Post-save payoff after capturing what helped from the change notice.
class ConfirmedRepeatHelpfulActionPayoff {
  const ConfirmedRepeatHelpfulActionPayoff({
    required this.title,
    required this.body,
    required this.evidenceLines,
    required this.primaryCta,
    required this.secondaryCta,
  });

  final String title;
  final String body;
  final List<String> evidenceLines;
  final String primaryCta;
  final String secondaryCta;
}

abstract final class EarlyFirstSignalEngine {
  EarlyFirstSignalEngine._();

  static const _signalEngine = SecondSessionSignalEngine();
  static const _journeyEngine = FirstThreeJourneyEngine();
  static const _maxSnippetLength = 72;

  static const _softeningPhrases = [
    'easier',
    'calmer',
    'less urgent',
    'stopped sooner',
    'did not spiral',
    "didn't spiral",
    'handled it better',
    'not as strong',
    'easier to stop',
  ];

  static const _triggerCapturePhrases = [
    'right before',
    'before i said',
    'before this',
    'before it came',
    'happened right before',
    'what happened before',
  ];

  static const _helpfulActionPhrases = [
    'helped',
    'asked for help',
    'paused before',
    'made it easier',
    'what helped',
  ];

  /// True when entry text contains cautious softening language from the user.
  static bool hasSofteningLanguage(String text) {
    final lower = text.toLowerCase();
    for (final phrase in _softeningPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  static bool hasTriggerCaptureLanguage(String text) {
    final lower = text.toLowerCase();
    for (final phrase in _triggerCapturePhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  static bool hasHelpfulActionLanguage(String text) {
    final lower = text.toLowerCase();
    for (final phrase in _helpfulActionPhrases) {
      if (lower.contains(phrase)) return true;
    }
    return false;
  }

  /// True when a later eligible entry shows a grounded, softer repeat return.
  static bool hasSofteningReturnEvidence(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return false;
    if (!hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3))) return false;

    for (var i = 3; i < eligible.length; i++) {
      final pair = eligible.sublist(i - 1, i + 1);
      if (pair.length < 2) continue;
      if (!_signalEngine.hasGroundedRepeatMatch(pair)) continue;
      if (hasSofteningLanguage(_entryText(eligible[i]))) return true;
    }
    return false;
  }

  /// True when trigger capture is supported by a milestone or entry evidence.
  static bool hasTriggerCaptureEvidence({
    required List<JournalEntry> entries,
    bool milestoneMarked = false,
  }) {
    if (milestoneMarked) return true;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return false;
    if (!hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3))) return false;

    for (var i = 3; i < eligible.length; i++) {
      final pair = eligible.sublist(i - 1, i + 1);
      if (pair.length < 2) continue;
      if (!_signalEngine.hasGroundedRepeatMatch(pair)) continue;
      if (hasTriggerCaptureLanguage(_entryText(eligible[i]))) return true;
    }
    return false;
  }

  /// True when helpful-action capture is supported by a milestone or entries.
  static bool hasHelpfulActionEvidence({
    required List<JournalEntry> entries,
    bool milestoneMarked = false,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return false;
    if (!hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3))) return false;

    final hasSofteningContext = hasSofteningReturnEvidence(entries) ||
        buildChangeNotice(entries: entries) != null;
    if (!hasSofteningContext) return false;

    if (milestoneMarked) return true;

    if (eligible.length < 5) return false;

    final beforeLatest = eligible.sublist(0, eligible.length - 1);
    if (!hasSofteningReturnEvidence(beforeLatest) &&
        buildChangeNotice(entries: beforeLatest) == null) {
      return false;
    }

    return hasHelpfulActionLanguage(_entryText(eligible.last));
  }

  /// True when the archive already has a confirmed repeat foundation.
  static bool hasConfirmedRepeatFoundation(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return false;
    return hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3));
  }

  /// True when three eligible moments form a grounded repeat chain.
  static bool hasConfirmedRepeatAcrossThree(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length != 3) return false;
    return _signalEngine.hasGroundedRepeatMatch(eligible.sublist(0, 2)) &&
        _signalEngine.hasGroundedRepeatMatch(eligible.sublist(1, 3));
  }

  /// Returns a card model for 1–3 eligible entries when early proof applies.
  static EarlyFirstSignalModel? build({
    required List<JournalEntry> entries,
  }) {
    if (!ArchiveEvidenceQualityGate.allowsEarlySignals(entries)) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return null;

    if (eligible.length == 1) {
      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.oneEntryReceipt,
        title: EarlyFirstSignalCopy.oneEntryTitle,
        lines: [EarlyFirstSignalCopy.oneEntryBody],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }

    if (eligible.length == 2) {
      if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
        return const EarlyFirstSignalModel(
          kind: EarlyFirstSignalKind.twoEntryFirstSignal,
          title: EarlyFirstSignalCopy.twoEntryRelatedTitle,
          lines: [EarlyFirstSignalCopy.twoEntryRelatedBody],
          primaryCta: EarlyFirstSignalCopy.confirmRepeatCta,
        );
      }

      return const EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.twoEntryNoPattern,
        title: EarlyFirstSignalCopy.twoEntryNoPatternTitle,
        lines: [EarlyFirstSignalCopy.twoEntryNoPatternBody],
        primaryCta: EarlyFirstSignalCopy.addMomentCta,
      );
    }

    if (eligible.length == 3 &&
        (_journeyEngine.hasRepeatMatch(entries: eligible) ||
            hasConfirmedRepeatAcrossThree(eligible))) {
      final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
      final isStrong = evidence.isStrong;
      final groundedPhrases =
          ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
        evidence.phrases,
        eligible,
      );

      final summaryLines = <String>[
        if (isStrong)
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes
        else
          EarlyFirstSignalCopy.threeEntryFormingBody,
      ];

      return EarlyFirstSignalModel(
        kind: EarlyFirstSignalKind.threeEntryConfirmedRepeat,
        title: isStrong
            ? EarlyFirstSignalCopy.threeEntryConfirmedTitle
            : EarlyFirstSignalCopy.threeEntryFormingTitle,
        lines: summaryLines,
        evidenceHeading: groundedPhrases.isNotEmpty
            ? EarlyFirstSignalCopy.evidenceHeading
            : null,
        evidencePhrases: groundedPhrases,
        evidenceSupportLine: isStrong && groundedPhrases.isNotEmpty
            ? EarlyFirstSignalCopy.evidenceSupportLine
            : null,
        primaryCta: EarlyFirstSignalCopy.recordWhatHappensNextCta,
        secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
        returnPrompt: const EarlyFirstSignalReturnPrompt(
          title: EarlyFirstSignalCopy.returnPromptTitle,
          body: EarlyFirstSignalCopy.returnPromptBody,
          cta: EarlyFirstSignalCopy.recordTriggerNextTimeCta,
          guidedRecordPrompt: EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
        ),
      );
    }

    return null;
  }

  /// Payoff after saving from the confirmed-repeat trigger guided prompt.
  static ConfirmedRepeatTriggerPayoff? buildTriggerCapturePayoff({
    required List<JournalEntry> entries,
    required bool savedFromTriggerPrompt,
  }) {
    if (!savedFromTriggerPrompt) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return null;

    final priorThree = eligible.sublist(0, 3);
    if (!hasConfirmedRepeatAcrossThree(priorThree)) return null;

    final insight = EarlyArchiveInsightQualityEngine.build(entries: entries);

    return ConfirmedRepeatTriggerPayoff(
      title: EarlyFirstSignalCopy.triggerPayoffTitle,
      body: insight.triggerSummary != null
          ? '${insight.triggerSummary!} That gives ArchiveMe stronger evidence for what starts this loop.'
          : EarlyArchiveInsightQualityCopy.triggerPayoffBodyFallback,
      evidenceLines: [
        insight.repeatSummary ?? EarlyFirstSignalCopy.triggerPayoffRepeatEvidence,
        insight.triggerSummary ?? EarlyFirstSignalCopy.triggerPayoffTriggerEvidence,
      ],
      primaryCta: EarlyFirstSignalCopy.triggerPayoffPrimaryCta,
      secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
    );
  }

  /// Change notice when a later related entry sounds softer than before.
  static ConfirmedRepeatChangeNotice? buildChangeNotice({
    required List<JournalEntry> entries,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 4) return null;
    if (!hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3))) return null;

    final latestText = _entryText(eligible.last);
    if (!hasSofteningLanguage(latestText)) return null;
    if (!_signalEngine.hasGroundedRepeatMatch(
      eligible.sublist(eligible.length - 2),
    )) {
      return null;
    }

    final insight = EarlyArchiveInsightQualityEngine.build(entries: entries);

    return ConfirmedRepeatChangeNotice(
      title: EarlyFirstSignalCopy.changeNoticeTitle,
      body: insight.softeningSummary ??
          EarlyArchiveInsightQualityCopy.changeNoticeBodyFallback,
      evidenceLines: [
        insight.repeatSummary ?? EarlyFirstSignalCopy.changeNoticeRepeatEvidence,
        _softeningEvidenceLine(insight.softeningSummary) ??
            EarlyFirstSignalCopy.changeNoticeChangeEvidence,
      ],
      primaryCta: EarlyFirstSignalCopy.recordWhatHelpedCta,
      secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
      guidedRecordPrompt: EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
    );
  }

  /// Payoff after saving from the helpful-action guided prompt.
  static ConfirmedRepeatHelpfulActionPayoff? buildHelpfulActionPayoff({
    required List<JournalEntry> entries,
    required bool savedFromHelpfulActionPrompt,
  }) {
    if (!savedFromHelpfulActionPrompt) return null;

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 5) return null;
    if (!hasConfirmedRepeatAcrossThree(eligible.sublist(0, 3))) return null;

    final beforeHelpful = eligible.sublist(0, eligible.length - 1);
    if (buildChangeNotice(entries: beforeHelpful) == null) return null;

    final insight = EarlyArchiveInsightQualityEngine.build(entries: entries);

    return ConfirmedRepeatHelpfulActionPayoff(
      title: EarlyFirstSignalCopy.helpfulActionPayoffTitle,
      body: insight.helpfulActionSummary ??
          EarlyArchiveInsightQualityCopy.helpfulActionPayoffBodyFallback,
      evidenceLines: [
        insight.repeatSummary ??
            EarlyFirstSignalCopy.helpfulActionRepeatEvidence,
        _softeningEvidenceLine(insight.softeningSummary) ??
            EarlyFirstSignalCopy.helpfulActionChangeEvidence,
        insight.helpfulActionSummary ??
            EarlyFirstSignalCopy.helpfulActionCapturedEvidence,
      ],
      primaryCta: EarlyFirstSignalCopy.triggerPayoffPrimaryCta,
      secondaryCta: EarlyFirstSignalCopy.viewEvidenceCta,
    );
  }

  static List<EarlyFirstSignalEvidenceRow> _evidenceRows(
    List<JournalEntry> eligible,
  ) {
    final rows = <EarlyFirstSignalEvidenceRow>[];
    for (final entry in eligible) {
      final snippet = _snippet(_entryText(entry));
      if (snippet.isEmpty) continue;
      rows.add(
        EarlyFirstSignalEvidenceRow(
          timestampLabel: _timestampLabel(entry.createdAt),
          snippet: snippet,
        ),
      );
    }
    if (rows.length <= 3) return rows;
    return rows.sublist(rows.length - 3);
  }

  static String? _softeningEvidenceLine(String? softeningSummary) {
    if (softeningSummary == null) return null;
    final lower = softeningSummary.toLowerCase();
    if (lower.contains('less urgent')) {
      return 'Change: it sounded less urgent.';
    }
    if (lower.contains('easier to stop')) {
      return 'Change: it seemed easier to stop.';
    }
    if (lower.contains('calmer')) {
      return 'Change: it sounded calmer.';
    }
    return null;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String _snippet(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= _maxSnippetLength) return trimmed;
    return '${trimmed.substring(0, _maxSnippetLength - 1)}…';
  }

  static String _timestampLabel(DateTime createdAt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}';
  }
}
