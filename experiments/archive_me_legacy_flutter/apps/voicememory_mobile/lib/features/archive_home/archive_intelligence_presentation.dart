import '../../models/journal_entry.dart';
import '../activation/archive_home_summary.dart';
import '../activation/next_moment_prompt.dart';
import '../archive_analyst/archive_belief_visibility.dart';
import '../archive_beliefs/archive_belief_models.dart';
import '../archive_evidence/archive_evidence_guard.dart';

enum ArchiveIntelligenceSectionId {
  whatChanged,
  reasoning,
  supportingMoments,
  nextAction,
}

enum ArchiveIntelligenceSectionState { ready, pending, lowEvidence, empty }

enum ArchiveIntelligenceAction { none, recordMoment, viewEvidence, viewReview }

final class ArchiveIntelligenceEvidenceMoment {
  const ArchiveIntelligenceEvidenceMoment({
    required this.id,
    required this.entryId,
    required this.occurredAt,
    required this.excerpt,
    required this.hasAudio,
  });

  final String id;
  final String entryId;
  final DateTime occurredAt;
  final String excerpt;
  final bool hasAudio;
}

final class ArchiveIntelligenceSection {
  ArchiveIntelligenceSection({
    required this.id,
    required this.title,
    required this.state,
    required this.body,
    this.headline,
    this.confidencePercent,
    this.confidenceExplanation,
    List<ArchiveIntelligenceEvidenceMoment> moments = const [],
    this.action = ArchiveIntelligenceAction.none,
    this.actionLabel,
  }) : moments = List.unmodifiable(moments);

  final ArchiveIntelligenceSectionId id;
  final String title;
  final ArchiveIntelligenceSectionState state;
  final String? headline;
  final String body;
  final int? confidencePercent;
  final String? confidenceExplanation;
  final List<ArchiveIntelligenceEvidenceMoment> moments;
  final ArchiveIntelligenceAction action;
  final String? actionLabel;
}

final class ArchiveIntelligencePresentation {
  ArchiveIntelligencePresentation._({
    required this.isEmpty,
    required List<ArchiveIntelligenceSection> sections,
  }) : sections = List.unmodifiable(sections);

  static const sectionOrder = [
    ArchiveIntelligenceSectionId.whatChanged,
    ArchiveIntelligenceSectionId.reasoning,
    ArchiveIntelligenceSectionId.supportingMoments,
    ArchiveIntelligenceSectionId.nextAction,
  ];

  final bool isEmpty;
  final List<ArchiveIntelligenceSection> sections;

  ArchiveIntelligenceSection? section(ArchiveIntelligenceSectionId id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  factory ArchiveIntelligencePresentation.build({
    required List<JournalEntry> entries,
    required ArchiveBeliefsSnapshot? beliefs,
  }) {
    final eligibleEntries = ArchiveEvidenceGuard.eligibleEntries(entries);
    final summary = ArchiveHomeSummaryEngine.build(entries: entries);
    if (eligibleEntries.isEmpty) {
      return ArchiveIntelligencePresentation._(
        isEmpty: true,
        sections: [
          ArchiveIntelligenceSection(
            id: ArchiveIntelligenceSectionId.whatChanged,
            title: 'Your Archive Intelligence',
            state: ArchiveIntelligenceSectionState.empty,
            body: summary.body,
            action: ArchiveIntelligenceAction.recordMoment,
            actionLabel: summary.primaryCta ?? 'Record a moment',
          ),
        ],
      );
    }

    final selected = _selectBelief(beliefs);
    final moments = selected == null
        ? const <ArchiveIntelligenceEvidenceMoment>[]
        : _matchingMoments(selected, eligibleEntries);
    final lowEvidence =
        selected == null ||
        selected.section == ArchiveBeliefSection.emerging ||
        moments.length < 2;
    final changeLine = selected?.section == ArchiveBeliefSection.changing
        ? _nonBlank(selected?.conclusion)
        : null;
    final next = NextMomentPromptEngine.build(entries: entries);

    return ArchiveIntelligencePresentation._(
      isEmpty: false,
      sections: [
        ArchiveIntelligenceSection(
          id: ArchiveIntelligenceSectionId.whatChanged,
          title: 'What changed?',
          state: changeLine == null
              ? ArchiveIntelligenceSectionState.pending
              : lowEvidence
              ? ArchiveIntelligenceSectionState.lowEvidence
              : ArchiveIntelligenceSectionState.ready,
          headline: changeLine == null ? null : selected!.statement,
          body:
              changeLine ??
              'There is not enough reliable history yet to compare a change.',
        ),
        ArchiveIntelligenceSection(
          id: ArchiveIntelligenceSectionId.reasoning,
          title: 'Why ArchiveMe thinks that',
          state: selected == null
              ? ArchiveIntelligenceSectionState.pending
              : lowEvidence
              ? ArchiveIntelligenceSectionState.lowEvidence
              : ArchiveIntelligenceSectionState.ready,
          headline: selected?.statement,
          body:
              _nonBlank(selected?.whyExplanation) ??
              'ArchiveMe needs more supported moments before selecting a pattern.',
          confidencePercent: selected?.confidencePercent,
          confidenceExplanation: _confidenceExplanation(
            selected: selected,
            matchedMomentCount: moments.length,
            lowEvidence: lowEvidence,
          ),
        ),
        ArchiveIntelligenceSection(
          id: ArchiveIntelligenceSectionId.supportingMoments,
          title: 'Supporting moments',
          state: moments.isEmpty
              ? ArchiveIntelligenceSectionState.pending
              : lowEvidence
              ? ArchiveIntelligenceSectionState.lowEvidence
              : ArchiveIntelligenceSectionState.ready,
          body: moments.isEmpty
              ? 'No source moment can be linked reliably to this read yet.'
              : lowEvidence
              ? 'These saved words are early evidence, not a conclusion.'
              : 'These are the saved words supporting this read.',
          moments: moments,
        ),
        ArchiveIntelligenceSection(
          id: ArchiveIntelligenceSectionId.nextAction,
          title: 'What to record or test next',
          state: next == null
              ? ArchiveIntelligenceSectionState.pending
              : ArchiveIntelligenceSectionState.ready,
          headline: next?.title,
          body:
              next?.body ??
              'Record one specific moment so ArchiveMe has real evidence to compare.',
          action: _actionFor(next?.primaryAction),
          actionLabel: next?.primaryCta ?? 'Record a moment',
        ),
      ],
    );
  }

  static ArchiveBeliefCardModel? _selectBelief(
    ArchiveBeliefsSnapshot? beliefs,
  ) {
    if (beliefs == null) return null;
    final candidates = <ArchiveBeliefCardModel>[
      ...beliefs.changing,
      ...beliefs.current,
      ...beliefs.emerging,
      ...beliefs.homeBeliefs,
    ];
    final seen = <String>{};
    for (final candidate in candidates) {
      if (!seen.add(candidate.id)) continue;
      if (ArchiveBeliefVisibility.isVisibleBelief(
        statement: candidate.statement,
        confidencePercent: candidate.confidencePercent,
        evidenceCount: candidate.timeline.length,
      )) {
        return candidate;
      }
    }
    return null;
  }

  static List<ArchiveIntelligenceEvidenceMoment> _matchingMoments(
    ArchiveBeliefCardModel belief,
    List<JournalEntry> entries,
  ) {
    final moments = <ArchiveIntelligenceEvidenceMoment>[];
    final usedEntryIds = <String>{};
    for (final evidence in belief.timeline) {
      final quote = evidence.quote.trim();
      if (quote.isEmpty) continue;
      final normalizedQuote = _normalize(quote);
      JournalEntry? match;
      for (final entry in entries) {
        if (usedEntryIds.contains(entry.id)) continue;
        if (_normalize(entry.transcript).contains(normalizedQuote)) {
          match = entry;
          break;
        }
      }
      if (match == null || !usedEntryIds.add(match.id)) continue;
      moments.add(
        ArchiveIntelligenceEvidenceMoment(
          id: 'moment:${match.id}',
          entryId: match.id,
          occurredAt: match.createdAt,
          excerpt: quote,
          hasAudio: _nonBlank(match.localAudioReference) != null,
        ),
      );
    }
    return moments;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _confidenceExplanation({
    required ArchiveBeliefCardModel? selected,
    required int matchedMomentCount,
    required bool lowEvidence,
  }) {
    if (selected == null) {
      return 'Confidence is pending until more source moments support a read.';
    }
    if (lowEvidence) {
      return 'This is an early read with $matchedMomentCount linked '
          '${matchedMomentCount == 1 ? 'moment' : 'moments'}, so it may change.';
    }
    return '${selected.confidencePercent}% confidence, supported by '
        '$matchedMomentCount linked moments.';
  }

  static ArchiveIntelligenceAction _actionFor(
    NextMomentPromptAction? action,
  ) => switch (action) {
    NextMomentPromptAction.addMoment => ArchiveIntelligenceAction.recordMoment,
    NextMomentPromptAction.viewEvidence =>
      ArchiveIntelligenceAction.viewEvidence,
    NextMomentPromptAction.viewReview => ArchiveIntelligenceAction.viewReview,
    null => ArchiveIntelligenceAction.recordMoment,
  };
}
