import '../../models/journal_entry.dart';
import '../../product/loop_mode_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../interpretation/interpretation_read_model.dart';
import '../signal_journey/signal_journey_model.dart';
import 'capacity_loop_review_sections.dart';
import 'loop_mode_model.dart';

/// Definitions, text support, ranking bias, and loop-specific copy.
class LoopModeEngine {
  const LoopModeEngine();

  static const capacityYesTemplateIds = [
    'saying_yes_capacity',
    'disappoint_someone',
    'responsibility_before_help',
  ];

  static const proveEnoughTemplateIds = [
    'prove_enough',
    'achievement_feel_safe',
    'ignoring_rest_unsafe',
  ];

  LoopMode definitionFor(String id) {
    switch (id) {
      case LoopModeIds.capacityYes:
        return _capacityYes(active: false);
      case LoopModeIds.proveEnough:
        return _proveEnough(active: false);
      case LoopModeIds.relationshipReplay:
        return _stub(
          id: LoopModeIds.relationshipReplay,
          title: LoopModeCopy.relationshipReplayTitle,
          promise: LoopModeCopy.relationshipReplayPromise,
        );
      case LoopModeIds.avoidConversation:
        return _stub(
          id: LoopModeIds.avoidConversation,
          title: LoopModeCopy.avoidConversationTitle,
          promise: LoopModeCopy.avoidConversationPromise,
        );
      case LoopModeIds.repeatingHabit:
        return _stub(
          id: LoopModeIds.repeatingHabit,
          title: LoopModeCopy.repeatingHabitTitle,
          promise: LoopModeCopy.repeatingHabitPromise,
        );
      case LoopModeIds.notSure:
      default:
        return _stub(
          id: LoopModeIds.notSure,
          title: LoopModeCopy.notSureTitle,
          promise: LoopModeCopy.notSurePromise,
        );
    }
  }

  LoopMode activate(String id) {
    final now = DateTime.now();
    final base = definitionFor(id);
    return base.copyWith(active: true, startedAt: now, updatedAt: now);
  }

  bool textSupports(LoopMode mode, String text) {
    if (!mode.active &&
        mode.id != LoopModeIds.capacityYes &&
        mode.id != LoopModeIds.proveEnough) {
      return false;
    }
    final lower = text.toLowerCase();
    return mode.interpretationBiasTags.any((tag) => lower.contains(tag));
  }

  List<String> preferredTemplateIds(LoopMode mode) {
    if (mode.isCapacityYes) return capacityYesTemplateIds;
    if (mode.isProveEnough) return proveEnoughTemplateIds;
    return const [];
  }

  bool readMatchesLoop(LoopMode mode, String? readId) {
    if (readId == null) return false;
    return preferredTemplateIds(mode).contains(readId);
  }

  LoopProgressStatus progressStatus(LoopMode mode) {
    final count = mode.completedRecordingCount;
    if (count >= mode.targetRecordingCount) {
      return LoopProgressStatus.readyToReview;
    }
    if (count >= 2) return LoopProgressStatus.gettingClearer;
    if (count >= 1) return LoopProgressStatus.earlySignal;
    return LoopProgressStatus.lookingForFirstEvidence;
  }

  String progressStatusLabel(LoopProgressStatus status) {
    switch (status) {
      case LoopProgressStatus.lookingForFirstEvidence:
        return LoopModeCopy.progressLooking;
      case LoopProgressStatus.earlySignal:
        return LoopModeCopy.progressEarlySignal;
      case LoopProgressStatus.gettingClearer:
        return LoopModeCopy.progressGettingClearer;
      case LoopProgressStatus.readyToReview:
        return LoopModeCopy.progressReadyToReview;
    }
  }

  String progressFraction(LoopMode mode) =>
      '${mode.completedRecordingCount}/${mode.targetRecordingCount}';

  String nextPrompt(LoopMode mode, {int rotation = 0}) {
    if (mode.isCapacityYes) {
      return _rotatePrompt(LoopModeCopy.capacityNextPrompts, rotation, mode);
    }
    if (mode.isProveEnough) {
      return _rotatePrompt(LoopModeCopy.proveEnoughNextPrompts, rotation, mode);
    }
    return mode.activePrompt;
  }

  String _rotatePrompt(List<String> prompts, int rotation, LoopMode mode) {
    if (prompts.isEmpty) return mode.activePrompt;
    return prompts[rotation % prompts.length];
  }

  String journeyTitle(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityJourneyTitle;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughJourneyTitle;
    return mode.title;
  }

  String journeyProgressLabel(LoopMode mode, SignalJourney journey) {
    if (mode.isCapacityYes) {
      return LoopModeCopy.capacityProgress(journey.supportingCount);
    }
    if (mode.isProveEnough) {
      return LoopModeCopy.proveEnoughProgress(journey.supportingCount);
    }
    return '${journey.supportingCount} of ${journey.targetEvidenceCount} moments';
  }

  String journeyRecordTitle(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityRecordCardTitle;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughRecordCardTitle;
    return 'Record next evidence';
  }

  String journeyRecordBody(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityRecordCardBody;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughRecordCardBody;
    return mode.shortPromise;
  }

  String unsupportedTitle(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityUnsupportedTitle;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughUnsupportedTitle;
    return 'ArchiveMe did not see this loop clearly yet.';
  }

  String unsupportedPrompt(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityUnsupportedPrompt;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughUnsupportedPrompt;
    return 'Try recording what happened, what you did, and what felt heavy.';
  }

  String postSaveTitle(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityPostSaveTitle;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughPostSaveTitle;
    return 'ArchiveMe is checking this loop';
  }

  String postSaveSubtitle(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityPostSaveSubtitle;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughPostSaveSubtitle;
    return 'This is not treated as true yet. Your next moments will test whether it repeats.';
  }

  String wouldConfirmFor(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityWouldConfirm;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughWouldConfirm;
    return mode.confirmSignals.join(', ');
  }

  String wouldChallengeFor(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.capacityWouldChallenge;
    if (mode.isProveEnough) return LoopModeCopy.proveEnoughWouldChallenge;
    return mode.contradictionSignals.join(', ');
  }

  String reviewTitle(LoopMode mode) => mode.reviewTitle;

  String whatItCostSummary(LoopMode mode, List<JournalEntry> entries) {
    if (!mode.isCapacityYes) return '';
    final text = entries.map((e) => e.transcript.toLowerCase()).join(' ');
    final costs = <String>[];
    if (text.contains('tired') ||
        text.contains('drained') ||
        text.contains('exhausted')) {
      costs.add('energy felt lower after agreeing');
    }
    if (text.contains('pressure') || text.contains('stress')) {
      costs.add('pressure showed up afterward');
    }
    if (text.contains('disappoint') || text.contains('guilt')) {
      costs.add('guilt or fear of disappointing someone appeared');
    }
    if (text.contains('time') || text.contains('behind')) {
      costs.add('time or pace felt tighter');
    }
    if (costs.isEmpty) {
      return 'Cost is still unclear — the next moment may show what agreeing took from you.';
    }
    return costs.take(2).join('; ');
  }

  String whatRepeatedSummary(LoopMode mode, SignalJourney journey) {
    if (mode.isCapacityYes) {
      return 'Across ${journey.supportingCount} moments, agreeing before checking capacity may be repeating.';
    }
    return journey.signalTitle;
  }

  String proveWrongSummary(LoopMode mode) {
    if (mode.isCapacityYes) return LoopModeCopy.reviewProveWrongCapacity;
    if (mode.isProveEnough) return LoopModeCopy.reviewProveWrongProveEnough;
    return mode.contradictionSignals.join(', ');
  }

  /// Builds loop-specific review sections for capacity_yes — conservative only.
  CapacityLoopReviewSections buildCapacityReviewSections({
    required SignalJourney journey,
    required List<JournalEntry> entries,
    int promptRotation = 0,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final byId = {for (final e in eligible) e.id: e};
    final supporting = <JournalEntry>[];
    for (final id in journey.supportingMomentIds) {
      final entry = byId[id];
      if (entry != null) supporting.add(entry);
    }

    final combined = supporting
        .map((e) => e.transcript.toLowerCase())
        .join(' ');
    final whatRepeated =
        'Across ${journey.supportingCount} moments, agreeing, helping, or taking something on before checking room or capacity may be repeating.';

    return CapacityLoopReviewSections(
      loopTitle: LoopModeCopy.capacityReviewTitle,
      subtitle: LoopModeCopy.capacityReviewSubtitle,
      whatRepeated: whatRepeated,
      whatItSeemedToCost: _capacityCost(combined),
      commonTrigger: _capacityTrigger(supporting),
      whatChanged: _capacityChange(supporting),
      whatWouldProveThisWrong: LoopModeCopy.reviewProveWrongCapacity,
      nextYesPrompt: nextPrompt(
        _capacityYes(active: true),
        rotation: promptRotation,
      ),
      reviewConfidenceLabel: _capacityConfidence(supporting, journey),
    );
  }

  List<String> capacityCorrectionAlternatives() =>
      List<String>.from(LoopModeCopy.capacityCorrectionAlternatives);

  /// Builds loop-specific review sections for prove_enough — conservative only.
  CapacityLoopReviewSections buildProveEnoughReviewSections({
    required SignalJourney journey,
    required List<JournalEntry> entries,
    int promptRotation = 0,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final byId = {for (final e in eligible) e.id: e};
    final supporting = <JournalEntry>[];
    for (final id in journey.supportingMomentIds) {
      final entry = byId[id];
      if (entry != null) supporting.add(entry);
    }

    final combined = supporting
        .map((e) => e.transcript.toLowerCase())
        .join(' ');
    final whatRepeated =
        'Across ${journey.supportingCount} moments, doing more because stopping felt unsafe or not enough may be repeating.';

    return CapacityLoopReviewSections(
      loopTitle: LoopModeCopy.proveEnoughReviewTitle,
      subtitle: LoopModeCopy.proveEnoughReviewSubtitle,
      whatRepeated: whatRepeated,
      whatItSeemedToCost: _proveEnoughCost(combined),
      commonTrigger: _proveEnoughTrigger(supporting),
      whatChanged: _proveEnoughChange(supporting),
      whatWouldProveThisWrong: LoopModeCopy.reviewProveWrongProveEnough,
      nextYesPrompt: nextPrompt(
        _proveEnough(active: true),
        rotation: promptRotation,
      ),
      reviewConfidenceLabel: _capacityConfidence(supporting, journey),
    );
  }

  List<String> proveEnoughCorrectionAlternatives() =>
      List<String>.from(LoopModeCopy.proveEnoughCorrectionAlternatives);

  List<String> correctionAlternativesFor(LoopMode mode) {
    if (mode.isCapacityYes) return capacityCorrectionAlternatives();
    if (mode.isProveEnough) return proveEnoughCorrectionAlternatives();
    return const [];
  }

  String _capacityCost(String combined) {
    final costs = <String>[];
    if (combined.contains('pressure') || combined.contains('stress')) {
      costs.add('pressure may have shown up afterward');
    }
    if (combined.contains('tired') ||
        combined.contains('drained') ||
        combined.contains('exhausted') ||
        combined.contains('overload')) {
      costs.add('tiredness or overload may have followed');
    }
    if (combined.contains('time') ||
        combined.contains('behind') ||
        combined.contains('deadline')) {
      costs.add('time cost may have tightened');
    }
    if (combined.contains('guilt')) {
      costs.add('guilt may have appeared');
    }
    if (combined.contains('resent')) {
      costs.add('resentment may have surfaced');
    }
    if (combined.contains('disappoint')) {
      costs.add('fear of disappointing someone may have been part of it');
    }
    if (costs.isEmpty) return LoopModeCopy.reviewCostFallback;
    return costs.take(3).join('; ');
  }

  String _capacityTrigger(List<JournalEntry> supporting) {
    final combined = supporting
        .map((e) => e.transcript.toLowerCase())
        .join(' ');
    final triggers = <String>[];
    if (combined.contains('disappoint')) {
      triggers.add('not wanting to disappoint someone');
    }
    if (combined.contains('responsib')) {
      triggers.add('a sense of responsibility');
    }
    if (combined.contains('pressure') || combined.contains('stress')) {
      triggers.add('pressure');
    }
    if (combined.contains('said yes') ||
        combined.contains('agreed') ||
        combined.contains('quick')) {
      triggers.add('a habit of agreeing quickly');
    }
    if (combined.contains('avoid') ||
        combined.contains("couldn't say no") ||
        combined.contains('hard to say no')) {
      triggers.add('avoiding saying no');
    }
    if (triggers.isEmpty) {
      return 'The trigger is still unclear — the next moment may show what pushed the yes.';
    }
    return 'So far, this may involve ${triggers.take(3).join(', ')}.';
  }

  String _capacityChange(List<JournalEntry> supporting) {
    if (supporting.length < 2) {
      return 'Not enough difference yet across the moments so far.';
    }

    bool hasPressure(String text) =>
        text.contains('pressure') || text.contains('stress');
    bool hasDisappoint(String text) => text.contains('disappoint');
    bool hasTime(String text) =>
        text.contains('time') || text.contains('behind');

    final texts = supporting.map((e) => e.transcript.toLowerCase()).toList();
    final allPressure = texts.every(hasPressure);
    if (allPressure) {
      return 'The same pressure may be repeating across these moments.';
    }

    final firstTime = texts.firstWhere(hasTime, orElse: () => '');
    final laterDisappoint =
        texts.skip(1).any(hasDisappoint) && hasTime(texts.first);
    if (laterDisappoint && firstTime.isNotEmpty) {
      return 'The reason may be shifting — from time pressure toward disappointing someone.';
    }

    final costWords = ['tired', 'drained', 'guilt', 'resent', 'overload'];
    final earlyCost = costWords.any(texts.first.contains);
    final laterCost = texts.skip(1).any((t) => costWords.any(t.contains));
    if (!earlyCost && laterCost) {
      return 'What it seemed to cost may be getting clearer in later moments.';
    }

    return 'Not enough difference yet across the three moments.';
  }

  String _proveEnoughCost(String combined) {
    final costs = <String>[];
    if (combined.contains('tired') ||
        combined.contains('drained') ||
        combined.contains('exhausted') ||
        combined.contains('overload')) {
      costs.add('tiredness or overload may have followed');
    }
    if (combined.contains('time') ||
        combined.contains('behind') ||
        combined.contains('deadline')) {
      costs.add('time cost may have tightened');
    }
    if (combined.contains('pressure') || combined.contains('stress')) {
      costs.add('pressure may have shown up');
    }
    if (combined.contains('rest') &&
        (combined.contains('guilt') || combined.contains('unsafe'))) {
      costs.add('guilt around rest may have appeared');
    }
    if (combined.contains('never') ||
        combined.contains('not done') ||
        combined.contains('not enough')) {
      costs.add('a never-feeling-done sense may have lingered');
    }
    if (combined.contains('behind') || combined.contains('falling behind')) {
      costs.add('feeling behind may have persisted');
    }
    if (combined.contains('satisf') && combined.contains('not')) {
      costs.add('satisfaction may have stayed low');
    }
    if (costs.isEmpty) return LoopModeCopy.reviewCostFallback;
    return costs.take(3).join('; ');
  }

  String _proveEnoughTrigger(List<JournalEntry> supporting) {
    final combined = supporting
        .map((e) => e.transcript.toLowerCase())
        .join(' ');
    final triggers = <String>[];
    if (combined.contains('behind') || combined.contains('falling behind')) {
      triggers.add('feeling behind');
    }
    if (combined.contains('impressive') ||
        combined.contains('success') ||
        combined.contains('achievement')) {
      triggers.add('wanting to be impressive');
    }
    if (combined.contains('productive') || combined.contains('productivity')) {
      triggers.add('needing to feel productive');
    }
    if (combined.contains('stop') ||
        combined.contains('rest') ||
        combined.contains('afraid')) {
      triggers.add('fear of stopping');
    }
    if (combined.contains('prove') ||
        combined.contains('enough') ||
        combined.contains('not enough')) {
      triggers.add('pressure to prove enough');
    }
    if (triggers.isEmpty) {
      return 'The trigger is still unclear — the next moment may show what pushed the extra effort.';
    }
    return 'So far, this may involve ${triggers.take(3).join(', ')}.';
  }

  String _proveEnoughChange(List<JournalEntry> supporting) {
    if (supporting.length < 2) {
      return 'Not enough difference yet across the moments so far.';
    }

    bool hasBehind(String text) =>
        text.contains('behind') || text.contains('not enough');
    bool hasRestGuilt(String text) =>
        text.contains('rest') &&
        (text.contains('guilt') || text.contains('unsafe'));
    bool hasPressure(String text) =>
        text.contains('pressure') || text.contains('productive');

    final texts = supporting.map((e) => e.transcript.toLowerCase()).toList();
    if (texts.every(hasPressure)) {
      return 'The same pressure to be productive may be repeating.';
    }
    if (hasBehind(texts.first) && texts.skip(1).any(hasRestGuilt)) {
      return 'The reason may be shifting — from feeling behind toward guilt around rest.';
    }
    final costWords = ['tired', 'drained', 'overload', 'never', 'not done'];
    final earlyCost = costWords.any(texts.first.contains);
    final laterCost = texts.skip(1).any((t) => costWords.any(t.contains));
    if (!earlyCost && laterCost) {
      return 'What it seemed to cost may be getting clearer in later moments.';
    }
    return 'Not enough difference yet across the three moments.';
  }

  String _capacityConfidence(
    List<JournalEntry> supporting,
    SignalJourney journey,
  ) {
    final resolved = supporting.where((e) {
      final t = e.transcript.trim();
      return t.length >= ArchiveEvidenceGuard.minimumTranscriptChars;
    }).length;
    if (resolved >= journey.supportingCount && journey.supportingCount >= 3) {
      return LoopModeCopy.reviewConfidenceWorthWatching;
    }
    if (resolved >= 2) return LoopModeCopy.reviewConfidenceGettingClearer;
    return LoopModeCopy.reviewConfidenceEarly;
  }

  void applyLoopBoost(
    List<({InterpretationRead read, int score})> scored,
    LoopMode mode,
    String normalizedText,
  ) {
    if (!textSupports(mode, normalizedText)) return;
    final preferred = preferredTemplateIds(mode).toSet();
    for (var i = 0; i < scored.length; i++) {
      if (preferred.contains(scored[i].read.id)) {
        final item = scored[i];
        scored[i] = (read: item.read, score: item.score + 12);
      }
    }
  }

  LoopMode _proveEnough({required bool active}) {
    final now = DateTime.now();
    return LoopMode(
      id: LoopModeIds.proveEnough,
      title: LoopModeCopy.proveEnoughTitle,
      shortPromise: LoopModeCopy.proveEnoughPromise,
      active: active,
      startedAt: now,
      updatedAt: now,
      activePrompt: LoopModeCopy.proveEnoughHandoffPrompt,
      interpretationBiasTags: const [
        'prove',
        'enough',
        'behind',
        'achievement',
        'work',
        'more',
        'pressure',
        'productive',
        'impressive',
        'success',
        'falling behind',
        'not doing enough',
        'keep going',
        'stop',
        'rest',
        'guilt',
      ],
      confirmSignals: const [
        'kept working to feel okay',
        'did more to prove enough',
        'felt behind when stopping',
        'measured worth through output',
        'ignored rest because it felt unsafe',
        'chased achievement instead of relief',
      ],
      contradictionSignals: const [
        'freely chose effort',
        'felt satisfied',
        'rested without guilt',
        'stopped and felt okay',
        'worked from interest not pressure',
      ],
      reminderCopy: LoopModeCopy.proveEnoughReminderPrePromptBody,
      reviewTitle: LoopModeCopy.proveEnoughReviewTitle,
    );
  }

  LoopMode _capacityYes({required bool active}) {
    final now = DateTime.now();
    return LoopMode(
      id: LoopModeIds.capacityYes,
      title: 'Saying yes when I have no capacity',
      shortPromise:
          'Catch the moment you agree before checking whether you have room.',
      active: active,
      startedAt: now,
      updatedAt: now,
      activePrompt: LoopModeCopy.capacityHandoffPrompt,
      interpretationBiasTags: const [
        'saying yes',
        'agreed',
        'agree',
        'help',
        'capacity',
        'pressure',
        'time',
        'tired',
        'guilt',
        'disappoint',
        'responsibility',
      ],
      confirmSignals: const [
        'agreed before checking time',
        'felt pressure afterward',
        'helped to avoid disappointing someone',
        'took responsibility automatically',
      ],
      contradictionSignals: const [
        'freely chose it',
        'had enough capacity',
        'felt clear and willing',
        'no pressure or guilt',
      ],
      reminderCopy: LoopModeCopy.capacityReminderPrePromptBody,
      reviewTitle: LoopModeCopy.capacityReviewTitle,
    );
  }

  LoopMode _stub({
    required String id,
    required String title,
    required String promise,
  }) {
    final now = DateTime.now();
    return LoopMode(
      id: id,
      title: title,
      shortPromise: promise,
      active: false,
      startedAt: now,
      updatedAt: now,
      activePrompt: 'What happened, what you did, and what felt heavy?',
      interpretationBiasTags: const [],
      confirmSignals: const [],
      contradictionSignals: const [],
      reminderCopy: '',
      reviewTitle: 'ArchiveMe reviewed your loop',
    );
  }
}
