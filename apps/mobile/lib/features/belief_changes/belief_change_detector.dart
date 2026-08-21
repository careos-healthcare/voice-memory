import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_shift_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_shift_models.dart';
import 'package:archiveme_mobile/features/timeline/timeline_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Detects identity shifts — confidence, emerging, and fading beliefs.
class BeliefChangeDetector {
  const BeliefChangeDetector({
    this.timelineEngine = const BeliefTimelineEngine(),
    this.beliefShiftEngine = const BeliefShiftEngine(),
  });

  final BeliefTimelineEngine timelineEngine;
  final BeliefShiftEngine beliefShiftEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;
  static const int minEvidenceIds = 3;
  static const int minMagnitude = 12;
  static const int emergingPriorMax = 18;
  static const int emergingCurrentMin = 35;
  static const int disappearingPriorMin = 35;
  static const int disappearingCurrentMax = 22;

  List<BeliefChangeAlert> detect({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (!archiveHasMinimumEvidence(entries)) return const [];

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minEligibleEntries) return const [];

    final candidates = _beliefCandidates(entries, state);
    final alerts = <BeliefChangeAlert>[];
    final seen = <String>{};

    for (final belief in candidates) {
      final key = _normalize(belief);
      if (key.isEmpty || seen.contains(key)) continue;

      final alert = _alertForBelief(belief, eligible);
      if (alert != null) {
        seen.add(key);
        alerts.add(alert);
      }
    }

    final shifts = beliefShiftEngine.detect(
      entries: entries,
      currentBelief: state?.belief,
    );
    for (final report in shifts.reports) {
      for (final text in [report.originalBelief, report.newBelief]) {
        final key = _normalize(text);
        if (seen.contains(key)) continue;
        final alert = _shiftAlert(report, text, eligible);
        if (alert != null) {
          seen.add(key);
          alerts.add(alert);
        }
      }
    }

    alerts.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    return alerts.take(6).toList();
  }

  BeliefChangeAlert? _alertForBelief(
    String belief,
    List<JournalEntry> eligible,
  ) {
    final timeline = timelineEngine.build(
      entries: eligible,
      beliefText: belief,
    );

    int priorPercent;
    int currentPercent;
    String priorLabel;
    String currentLabel;

    if (timeline.points.length >= 2) {
      final prior = timeline.points.first;
      final current = timeline.points.last;
      priorPercent = prior.strengthPercent;
      currentPercent = current.strengthPercent;
      priorLabel = _monthLabel(prior.month, prior.year);
      currentLabel = _currentLabel(current.month, current.year);
    } else {
      final window = _windowPercents(eligible, belief);
      if (window == null) return null;
      priorPercent = window.$1;
      currentPercent = window.$2;
      priorLabel = 'Earlier';
      currentLabel = 'Today';
    }

    final delta = currentPercent - priorPercent;
    final magnitude = delta.abs();
    if (magnitude < minMagnitude) return null;

    final evidence = _evidenceForBelief(eligible, belief);
    if (evidence.length < minEvidenceIds) return null;

    BeliefChangeAlertType type;
    String headline;

    if (priorPercent < emergingPriorMax &&
        currentPercent >= emergingCurrentMin &&
        delta >= minMagnitude) {
      type = BeliefChangeAlertType.newBeliefEmerging;
      headline = 'A new belief may be emerging.';
    } else if (priorPercent >= disappearingPriorMin &&
        currentPercent <= disappearingCurrentMax &&
        delta <= -minMagnitude) {
      type = BeliefChangeAlertType.disappearingBelief;
      headline = 'A belief may be fading from your archive.';
    } else if (delta <= -minMagnitude) {
      type = BeliefChangeAlertType.confidenceDecrease;
      headline = 'Your archive believes this less than before.';
    } else if (delta >= minMagnitude) {
      type = BeliefChangeAlertType.confidenceIncrease;
      headline = 'Your archive believes this more than before.';
    } else {
      return null;
    }

    return BeliefChangeAlert(
      id: 'belief-change:${type.name}:${belief.hashCode}',
      type: type,
      headline: headline,
      beliefStatement: belief,
      priorLabel: priorLabel,
      priorPercent: priorPercent,
      currentLabel: currentLabel,
      currentPercent: currentPercent,
      magnitude: magnitude,
      evidenceEntryIds: evidence,
      confidence: (58 + magnitude).clamp(55, 92),
    );
  }

  BeliefChangeAlert? _shiftAlert(
    BeliefShiftReport report,
    String focusBelief,
    List<JournalEntry> eligible,
  ) {
    final fromTimeline = _alertForBelief(focusBelief, eligible);
    if (fromTimeline != null) return fromTimeline;

    if (report.evidenceIds.length < minEvidenceIds) return null;
    return BeliefChangeAlert(
      id: 'belief-shift:${report.id}:${focusBelief.hashCode}',
      type: BeliefChangeAlertType.confidenceIncrease,
      headline: 'Your archive traced a belief shift.',
      beliefStatement: focusBelief,
      priorLabel: 'Earlier',
      priorPercent: 38,
      currentLabel: 'Now',
      currentPercent: report.confidence.clamp(42, 88),
      magnitude: 18,
      evidenceEntryIds: report.evidenceIds.take(6).toList(),
      confidence: report.confidence,
    );
  }

  static const List<String> _trackedBeliefPhrases = [
    'I need external validation',
    'I can trust myself',
    'I need approval before I decide',
    'I am becoming more confident',
  ];

  Set<String> _beliefCandidates(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final out = <String>{};
    final primary =
        state?.belief?.trim() ?? archiveBeliefFromReflections(entries);
    if (primary != null && primary.length >= 12) out.add(primary);

    out.addAll(_trackedBeliefPhrases);

    for (final e in archiveEligibleEvidenceEntries(entries).reversed.take(12)) {
      final obs = e.reflection.concreteObservation.trim();
      if (obs.length >= 16 && obs.length <= 120) out.add(obs);
    }

    return out;
  }

  (int, int)? _windowPercents(List<JournalEntry> eligible, String belief) {
    final prior = _entriesInWindow(
      eligible,
      const Duration(days: 45),
      excludeRecentDays: 21,
    );
    final recent = _entriesInWindow(eligible, const Duration(days: 21));
    if (prior.length < 2 || recent.length < 2) {
      final mid = eligible.length ~/ 2;
      if (mid < 1 || mid >= eligible.length) return null;
      final first = eligible.sublist(0, mid);
      final second = eligible.sublist(mid);
      final p1 = _percentMatching(first, belief);
      final p2 = _percentMatching(second, belief);
      return (p1, p2);
    }
    return (_percentMatching(prior, belief), _percentMatching(recent, belief));
  }

  static int _percentMatching(List<JournalEntry> entries, String belief) {
    if (entries.isEmpty) return 0;
    final keywords = belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
    if (keywords.isEmpty) return 0;
    var hits = 0;
    for (final e in entries) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) hits++;
    }
    return ((hits / entries.length) * 100).round();
  }

  static List<JournalEntry> _entriesInWindow(
    List<JournalEntry> entries,
    Duration window, {
    int excludeRecentDays = 0,
  }) {
    final now = DateTime.now();
    final end = now.subtract(Duration(days: excludeRecentDays));
    final start = end.subtract(window);
    return entries
        .where((e) => !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .toList();
  }

  List<String> _evidenceForBelief(List<JournalEntry> eligible, String belief) {
    final keywords = belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
    if (keywords.isEmpty) {
      return eligible.reversed.take(4).map((e) => e.id).toList();
    }

    final ids = <String>[];
    for (final e in eligible.reversed) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) ids.add(e.id);
      if (ids.length >= 6) break;
    }
    return ids;
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _monthLabel(int month, int year) {
    final now = DateTime.now();
    if (month == now.month && year == now.year) return 'Today';
    return '${timelineMonthLabel(month)} $year';
  }

  static String _currentLabel(int month, int year) {
    final now = DateTime.now();
    if (month == now.month && year == now.year) return 'Today';
    return '${timelineMonthLabel(month)} $year';
  }
}

/// Maps alerts to archive explanation routes.
ArchiveInsightRef insightRefForBeliefChangeAlert(
  BeliefChangeAlert alert,
  int index,
) {
  return switch (alert.type) {
    BeliefChangeAlertType.newBeliefEmerging ||
    BeliefChangeAlertType.confidenceIncrease => ArchiveInsightRef.beliefChange(
      index,
    ),
    BeliefChangeAlertType.confidenceDecrease ||
    BeliefChangeAlertType.disappearingBelief => ArchiveInsightRef.belief(),
  };
}