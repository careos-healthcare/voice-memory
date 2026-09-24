import 'package:archiveme_mobile/features/belief_changes/belief_change_detector.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_shift_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_shift_models.dart';
import 'package:archiveme_mobile/features/challenging_questions/stance_anchor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Finds historical moments where a stance on one topic moved enough to ask
/// about. Uses the belief-change detector, shift reports, and stored version
/// deltas. A move counts when its magnitude reaches
/// [BeliefChangeDetector.minMagnitude], or when a shift report already passed
/// the shift engine's confidence floor.
class StanceEvolutionScanner {
  const StanceEvolutionScanner({
    this.shiftEngine = const BeliefShiftEngine(),
    this.changeDetector = const BeliefChangeDetector(),
  });

  final BeliefShiftEngine shiftEngine;
  final BeliefChangeDetector changeDetector;

  List<StanceAnchor> scan({
    required List<JournalEntry> entries,
    BeliefEvolutionState? evolution,
  }) {
    final anchors = <StanceAnchor>[
      for (final report in shiftEngine.detect(entries: entries).reports)
        ..._fromShift(report),
      for (final alert in changeDetector.detect(entries: entries))
        ..._fromAlert(alert),
      ..._fromEvolution(evolution),
    ];

    final seen = <String>{};
    final unique = <StanceAnchor>[];
    for (final anchor in anchors) {
      if (anchor.earlierStance.trim().isEmpty ||
          anchor.laterStance.trim().isEmpty) {
        continue;
      }
      if (anchor.earlierStance.trim().toLowerCase() ==
          anchor.laterStance.trim().toLowerCase()) {
        continue;
      }
      if (!seen.add(anchor.dedupeKey)) continue;
      unique.add(anchor);
    }
    unique.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    return unique;
  }

  static List<StanceAnchor> _fromShift(BeliefShiftReport report) {
    if (report.confidence < BeliefShiftEngine.minConfidence) return const [];
    final timeline = report.evolutionTimeline;
    final earlier = timeline.isNotEmpty
        ? timeline.first.beliefText
        : report.originalBelief;
    final later = timeline.length > 1
        ? timeline.last.beliefText
        : report.newBelief;
    final topic = report.sharedTopics.isEmpty
        ? _topicFrom(later)
        : report.sharedTopics.first;
    return [
      StanceAnchor(
        topic: topic,
        earlierStance: earlier.trim(),
        laterStance: later.trim(),
        magnitude: report.confidence,
        earlierEntryId: timeline.isEmpty ? '' : timeline.first.entryId,
        laterEntryId: timeline.length < 2 ? '' : timeline.last.entryId,
      ),
    ];
  }

  static List<StanceAnchor> _fromAlert(BeliefChangeAlert alert) {
    if (alert.magnitude < BeliefChangeDetector.minMagnitude) return const [];
    final topic = alert.beliefStatement.trim().isEmpty
        ? 'this theme'
        : alert.beliefStatement.trim();
    final ids = alert.evidenceEntryIds;
    return [
      StanceAnchor(
        topic: topic,
        earlierStance: '${alert.priorLabel} (${alert.priorPercent}%)',
        laterStance: '${alert.currentLabel} (${alert.currentPercent}%)',
        magnitude: alert.magnitude,
        earlierEntryId: ids.isEmpty ? '' : ids.first,
        laterEntryId: ids.length < 2 ? '' : ids.last,
      ),
    ];
  }

  static List<StanceAnchor> _fromEvolution(BeliefEvolutionState? evolution) {
    final versions = evolution?.versions ?? const <BeliefVersionRecord>[];
    if (versions.length < 2) return const [];
    final earlier = versions.first;
    final later = versions.last;
    final magnitude = (later.confidence - earlier.confidence).abs();
    if (magnitude < BeliefChangeDetector.minMagnitude) return const [];
    if (earlier.beliefText.trim().toLowerCase() ==
        later.beliefText.trim().toLowerCase()) {
      return const [];
    }
    return [
      StanceAnchor(
        topic: _topicFrom(later.beliefText),
        earlierStance: earlier.beliefText.trim(),
        laterStance: later.beliefText.trim(),
        magnitude: magnitude,
        earlierEntryId: earlier.supportingEntryIds.isEmpty
            ? ''
            : earlier.supportingEntryIds.first,
        laterEntryId: later.supportingEntryIds.isEmpty
            ? ''
            : later.supportingEntryIds.last,
      ),
    ];
  }

  static String _topicFrom(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(6);
    final topic = words.join(' ');
    return topic.isEmpty ? 'this theme' : topic;
  }
}
