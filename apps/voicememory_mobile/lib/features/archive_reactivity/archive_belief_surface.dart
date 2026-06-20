import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../../models/journal_entry.dart';
import '../app_review/archive_app_review_access_gate.dart';
import '../archive_beliefs/archive_belief_models.dart';
import '../patterns/transcript_evidence_extractor.dart';
import 'archive_belief_specificity.dart';
import 'archive_change_timeline.dart';
import 'archive_display_copy_guard.dart';
import 'archive_lens.dart';
import 'archive_lens_return_result.dart';
import 'archive_return_value_proof.dart';
import 'archive_thought_map.dart';

enum ArchiveBeliefSurfaceMode {
  belief,
  preview,
}

class ArchiveBeliefSurface {
  const ArchiveBeliefSurface({
    required this.mode,
    required this.beliefSummary,
    required this.evidenceSummary,
    required this.whatChangedSummary,
    required this.confidenceLabel,
    this.recordNextPrompt,
    this.previewBullets = const [],
    this.beliefChangedOrSoftened = false,
    this.hasEnoughEvidence = false,
  });

  final ArchiveBeliefSurfaceMode mode;
  final String beliefSummary;
  final String evidenceSummary;
  final String whatChangedSummary;
  final String confidenceLabel;
  final String? recordNextPrompt;
  final List<String> previewBullets;
  final bool beliefChangedOrSoftened;
  final bool hasEnoughEvidence;

  bool get isPreview => mode == ArchiveBeliefSurfaceMode.preview;

  bool get shouldDisplay =>
      beliefSummary.trim().isNotEmpty && evidenceSummary.trim().isNotEmpty;
}

abstract class ArchiveBeliefSurfaceCopy {
  ArchiveBeliefSurfaceCopy._();

  static const cardTitle = 'Your archive currently believes this about you';
  static const previewTitle =
      "Here's what ArchiveMe will track if this keeps appearing.";
  static const previewLabel = 'Preview / watch state';
  static const beliefLabel = 'Your archive currently believes';
  static const evidenceLabel = 'Evidence';
  static const whatChangedLabel = 'What changed';
  static const recordNextCta = 'Record this next';
}

abstract class ArchiveBeliefSurfaceLog {
  ArchiveBeliefSurfaceLog._();

  static void resolved({
    required ArchiveBeliefSurfaceMode mode,
    required String confidence,
  }) {
    debugPrint(
      'ARCHIVEME_BELIEF_SURFACE_RESOLVED mode=${mode.name} confidence=$confidence',
    );
  }

  static void shown({required String surface}) {
    debugPrint('ARCHIVEME_BELIEF_SURFACE_SHOWN surface=$surface');
  }

  static void promptTapped() {
    debugPrint('ARCHIVEME_BELIEF_SURFACE_PROMPT_TAPPED');
  }
}

abstract class ArchiveBeliefSurfacePlacement {
  ArchiveBeliefSurfacePlacement._();

  @visibleForTesting
  static bool? blockForTest;

  static bool isEnvironmentBlocked() {
    if (blockForTest != null) return blockForTest!;
    if (ArchiveAppReviewAccessGate.isEnabled) return true;
    return false;
  }

  static bool shouldShow({
    required int entryCount,
    required bool firstValueRescueActive,
    required ArchiveBeliefSurface? surface,
  }) {
    if (isEnvironmentBlocked()) return false;
    if (entryCount < 1) return false;
    if (firstValueRescueActive) return false;
    if (surface == null || !surface.shouldDisplay) return false;
    return true;
  }
}

abstract class ArchiveBeliefSurfaceResolver {
  ArchiveBeliefSurfaceResolver._();

  static const _banned = [
    'therapy',
    'diagnosis',
    'treatment',
    'cure',
    'mental health',
    'fix your thoughts',
    'negative thoughts',
    'bad behaviour',
    'addictive',
    'you always',
    'this proves',
    'coach',
  ];

  static ArchiveBeliefSurface? resolve({
    required List<JournalEntry> entries,
    required ArchiveThoughtMap? thoughtMap,
    required ArchiveChangeTimeline? changeTimeline,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveBeliefSpecificity? specificity,
    required ArchiveReturnValueProofResult? latestReturnResult,
    required ArchiveLensInsight? latestLens,
    required ArchiveLensReturnResult? latestLensReturnResult,
  }) {
    final usable = entries
        .where((entry) => entry.transcript.trim().isNotEmpty)
        .toList();
    if (usable.isEmpty) return null;

    final weakEvidence = usable.length <= 1 ||
        (changeTimeline != null && !changeTimeline.hasMeaningfulItems);
    if (weakEvidence) {
      return _preview(
        entries: usable,
        thoughtMap: thoughtMap,
        changeTimeline: changeTimeline,
      );
    }

    final beliefCard = _primaryBelief(beliefs, thoughtMap);
    final resolvedSpecificity = specificity ??
        (beliefCard == null
            ? null
            : ArchiveBeliefSpecificityResolver.resolve(
                ArchiveBeliefSpecificityInput(
                  belief: beliefCard,
                  entries: usable,
                  latestEntry: usable.last,
                  repeatedPhrases:
                      TranscriptEvidenceExtractor.extractRepeatedPhrases(
                    usable.map((e) => e.transcript).toList(),
                  ),
                  archiveLensInsight: latestLens,
                  returnResult: latestLensReturnResult,
                ),
              ));

    if (resolvedSpecificity != null && resolvedSpecificity.hasEnoughEvidence) {
      return _fromSpecificity(
        specificity: resolvedSpecificity,
        entries: usable,
        thoughtMap: thoughtMap,
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
      );
    }

    if (thoughtMap != null && thoughtMap.hasEnoughEvidence) {
      return _fromThoughtMap(
        map: thoughtMap,
        entries: usable,
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
      );
    }

    return _cautiousBelief(
      entries: usable,
      beliefs: beliefs,
      changeTimeline: changeTimeline,
    );
  }

  static String recordRouteFor(ArchiveBeliefSurface surface) {
    final prompt = surface.recordNextPrompt?.trim().isNotEmpty == true
        ? surface.recordNextPrompt!
        : 'Record the next time this appears.';
    final params = <String, String>{
      'guidedPromptText': prompt,
      'guidedPromptId': 'belief_surface',
      'guidedPromptNodeKey': 'changeTimeline',
      'prompt': prompt,
    };
    return Uri(path: '/record', queryParameters: params).toString();
  }

  static ArchiveBeliefCardModel? _primaryBelief(
    ArchiveBeliefsSnapshot? beliefs,
    ArchiveThoughtMap? thoughtMap,
  ) {
    if (beliefs != null) {
      if (beliefs.current.isNotEmpty) return beliefs.current.first;
      if (beliefs.homeBeliefs.isNotEmpty) return beliefs.homeBeliefs.first;
      if (beliefs.emerging.isNotEmpty) return beliefs.emerging.first;
    }
    if (thoughtMap != null && thoughtMap.title.trim().isNotEmpty) {
      return ArchiveBeliefCardModel(
        id: thoughtMap.mapId,
        statement: thoughtMap.title,
        confidencePercent: 60,
        evidenceSummary: thoughtMap.strongestQuote,
        whyExplanation: thoughtMap.supportQuote,
        section: ArchiveBeliefSection.current,
      );
    }
    return null;
  }

  static ArchiveBeliefSurface? _fromSpecificity({
    required ArchiveBeliefSpecificity specificity,
    required List<JournalEntry> entries,
    required ArchiveThoughtMap? thoughtMap,
    required ArchiveChangeTimeline? changeTimeline,
    required ArchiveReturnValueProofResult? latestReturnResult,
  }) {
    final beliefSummary = _guard(
      specificity.specificTitle,
      allowShortLabel: true,
    );
    final evidenceSummary = _guard(
      _evidenceFromSpecificity(specificity, entries, thoughtMap),
    );
    final whatChanged = _guard(
      _whatChangedLine(
        specificity: specificity,
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
      ),
    );
    final recordNext = _guard(specificity.nextEvidenceMission);
    if ([beliefSummary, evidenceSummary, whatChanged].any((v) => v.isEmpty)) {
      return null;
    }
    final surface = ArchiveBeliefSurface(
      mode: ArchiveBeliefSurfaceMode.belief,
      beliefSummary: beliefSummary,
      evidenceSummary: evidenceSummary,
      whatChangedSummary: whatChanged,
      confidenceLabel: specificity.confidenceLabel,
      recordNextPrompt: recordNext.isEmpty ? null : recordNext,
      beliefChangedOrSoftened: _beliefChangedOrSoftened(
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
        whatChanged: whatChanged,
      ),
      hasEnoughEvidence: true,
    );
    ArchiveBeliefSurfaceLog.resolved(
      mode: surface.mode,
      confidence: surface.confidenceLabel,
    );
    return surface;
  }

  static ArchiveBeliefSurface? _fromThoughtMap({
    required ArchiveThoughtMap map,
    required List<JournalEntry> entries,
    required ArchiveChangeTimeline? changeTimeline,
    required ArchiveReturnValueProofResult? latestReturnResult,
  }) {
    final quote = map.strongestQuote.trim();
    final beliefSummary = _guard(
      quote.isNotEmpty
          ? '"$quote"'
          : map.title.trim(),
      allowShortLabel: true,
    );
    final evidenceSummary = _guard(
      'Seen across ${entries.length} recording${entries.length == 1 ? '' : 's'}. '
      'Strongest signal: ${map.behaviourNode.text.trim().isNotEmpty ? map.behaviourNode.text.trim() : map.thoughtNode.text.trim()}.',
    );
    final whatChanged = _guard(
      _whatChangedLine(
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
      ),
    );
    if ([beliefSummary, evidenceSummary].any((v) => v.isEmpty)) return null;
    final recordNext = changeTimeline?.nextBestPrompt ?? map.nextTestNode.text;
    final surface = ArchiveBeliefSurface(
      mode: ArchiveBeliefSurfaceMode.belief,
      beliefSummary: beliefSummary,
      evidenceSummary: evidenceSummary,
      whatChangedSummary: whatChanged.isEmpty
          ? 'ArchiveMe is watching what changes on the next return.'
          : whatChanged,
      confidenceLabel: map.confidenceLabel.trim().isNotEmpty
          ? map.confidenceLabel
          : 'Based on your words',
      recordNextPrompt: _guard(recordNext).isEmpty ? null : _guard(recordNext),
      beliefChangedOrSoftened: _beliefChangedOrSoftened(
        changeTimeline: changeTimeline,
        latestReturnResult: latestReturnResult,
        whatChanged: whatChanged,
      ),
      hasEnoughEvidence: map.hasEnoughEvidence,
    );
    ArchiveBeliefSurfaceLog.resolved(
      mode: surface.mode,
      confidence: surface.confidenceLabel,
    );
    return surface;
  }

  static ArchiveBeliefSurface? _cautiousBelief({
    required List<JournalEntry> entries,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveChangeTimeline? changeTimeline,
  }) {
    final belief = beliefs?.current.firstOrNull ??
        beliefs?.homeBeliefs.firstOrNull;
    final beliefSummary = _guard(
      belief != null
          ? 'Your archive is starting to notice: "${belief.statement.trim()}".'
          : 'Your archive is starting to notice one thread across your recordings.',
      allowShortLabel: true,
    );
    final evidenceSummary = _guard(
      belief?.evidenceSummary.trim().isNotEmpty == true
          ? belief!.evidenceSummary
          : 'Not enough evidence yet, but this is what ArchiveMe will watch.',
    );
    final whatChanged = _guard(
      changeTimeline?.summaryLine.trim().isNotEmpty == true
          ? changeTimeline!.summaryLine
          : 'This may be a pattern. One more focused recording may make it clearer.',
    );
    if ([beliefSummary, evidenceSummary].any((v) => v.isEmpty)) return null;
    final surface = ArchiveBeliefSurface(
      mode: ArchiveBeliefSurfaceMode.belief,
      beliefSummary: beliefSummary,
      evidenceSummary: evidenceSummary,
      whatChangedSummary: whatChanged,
      confidenceLabel: 'Early signal',
      recordNextPrompt: changeTimeline?.nextBestPrompt,
      beliefChangedOrSoftened: changeTimeline?.hasSofteningChange == true ||
          changeTimeline?.hasHelpfulChange == true,
      hasEnoughEvidence: false,
    );
    ArchiveBeliefSurfaceLog.resolved(
      mode: surface.mode,
      confidence: surface.confidenceLabel,
    );
    return surface;
  }

  static ArchiveBeliefSurface? _preview({
    required List<JournalEntry> entries,
    required ArchiveThoughtMap? thoughtMap,
    required ArchiveChangeTimeline? changeTimeline,
  }) {
    final firstSeen = changeTimeline?.timelineItems
        .where((item) => item.type == ArchiveChangeTimelineItemType.loopFirstSeen)
        .firstOrNull;
    final firstSeenLine = firstSeen?.evidenceLine.trim().isNotEmpty == true
        ? firstSeen!.evidenceLine
        : (thoughtMap?.strongestQuote.trim().isNotEmpty == true
            ? "The strongest clue was: '${thoughtMap!.strongestQuote.trim()}'."
            : 'ArchiveMe will watch the first clear signal from your recording.');

    final bullets = <String>[
      _guard(firstSeenLine.isEmpty
          ? 'Pattern first seen when the thread appears in your words.'
          : 'Pattern first seen: $firstSeenLine'),
      _guard('What would count as a repeat: checking or the watched loop appears again.'),
      _guard('What would count as softening: less urgent language or easier to stop.'),
      _guard(
        changeTimeline?.nextBestPrompt?.trim().isNotEmpty == true
            ? 'What to record next: ${changeTimeline!.nextBestPrompt}'
            : 'What to record next: Record the next time this appears.',
      ),
    ].where((line) => line.isNotEmpty).toList();

    final recordNext = changeTimeline?.nextBestPrompt ??
        thoughtMap?.nextTestNode.text ??
        'Record the next time this appears.';

    final surface = ArchiveBeliefSurface(
      mode: ArchiveBeliefSurfaceMode.preview,
      beliefSummary: _guard(
        "Here's what ArchiveMe will track if this keeps appearing.",
        allowShortLabel: true,
      ),
      evidenceSummary: _guard(
        entries.length == 1
            ? 'Preview from your first recording. This is not a conclusion yet.'
            : 'Preview from limited evidence. ArchiveMe is still watching.',
      ),
      whatChangedSummary: _guard(
        'Not enough evidence yet, but this is what ArchiveMe will watch.',
      ),
      confidenceLabel: 'Preview',
      recordNextPrompt: _guard(recordNext).isEmpty ? null : _guard(recordNext),
      previewBullets: bullets,
      hasEnoughEvidence: false,
    );
    if (!surface.shouldDisplay) return null;
    ArchiveBeliefSurfaceLog.resolved(
      mode: surface.mode,
      confidence: surface.confidenceLabel,
    );
    return surface;
  }

  static String _evidenceFromSpecificity(
    ArchiveBeliefSpecificity specificity,
    List<JournalEntry> entries,
    ArchiveThoughtMap? thoughtMap,
  ) {
    final parts = <String>[
      'Seen across ${entries.length} recording${entries.length == 1 ? '' : 's'}.',
    ];
    if (specificity.strongestQuote.trim().isNotEmpty) {
      parts.add("Strongest signal: '${specificity.strongestQuote.trim()}'.");
    } else if (thoughtMap != null && thoughtMap.behaviourNode.text.isNotEmpty) {
      parts.add('Strongest signal: ${thoughtMap.behaviourNode.text.trim()}.');
    } else {
      parts.add(specificity.evidenceSummaryLine);
    }
    return parts.join(' ');
  }

  static String _whatChangedLine({
    ArchiveBeliefSpecificity? specificity,
    ArchiveChangeTimeline? changeTimeline,
    ArchiveReturnValueProofResult? latestReturnResult,
  }) {
    if (changeTimeline?.helpfulChange != null) {
      return changeTimeline!.helpfulChange!.changeLine;
    }
    if (changeTimeline?.strongestChange?.type ==
        ArchiveChangeTimelineItemType.urgencySoftened) {
      return changeTimeline!.strongestChange!.changeLine;
    }
    if (latestReturnResult?.resultType ==
        ArchiveReturnValueProofResultType.softened) {
      return latestReturnResult!.comparisonLine;
    }
    if (specificity?.whatChangedLine.trim().isNotEmpty == true) {
      return specificity!.whatChangedLine;
    }
    if (changeTimeline?.summaryLine.trim().isNotEmpty == true) {
      return changeTimeline!.summaryLine;
    }
    return 'ArchiveMe is watching what changes on the next return.';
  }

  static bool _beliefChangedOrSoftened({
    required ArchiveChangeTimeline? changeTimeline,
    required ArchiveReturnValueProofResult? latestReturnResult,
    required String whatChanged,
  }) {
    if (changeTimeline?.hasSofteningChange == true ||
        changeTimeline?.hasHelpfulChange == true) {
      return true;
    }
    if (latestReturnResult?.resultType ==
        ArchiveReturnValueProofResultType.softened) {
      return true;
    }
    final lower = whatChanged.toLowerCase();
    return lower.contains('soften') ||
        lower.contains('helped') ||
        lower.contains('changed') ||
        lower.contains('less urgent');
  }

  static String _guard(String raw, {bool allowShortLabel = false}) {
    if (_containsBanned([raw])) return '';
    return ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'evidence',
      text: raw,
      allowShortLabel: allowShortLabel,
      requireSpecificity: false,
    );
  }

  static bool _containsBanned(List<String> values) {
    final blob = values.join(' ').toLowerCase();
    return _banned.any(blob.contains);
  }
}
