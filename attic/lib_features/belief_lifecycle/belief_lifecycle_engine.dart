import '../../models/journal_entry.dart';
import '../archive_analyst/archive_analyst_confidence_engine.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/belief_timeline_engine.dart';
import '../archive_explanations/explanation_models.dart';
import '../belief_evolution/belief_evolution_models.dart';
import 'belief_lifecycle_copy.dart';
import 'belief_lifecycle_models.dart';

/// Derives belief lifecycle from timeline, evidence split, and evolution versions.
class BeliefLifecycleEngine {
  const BeliefLifecycleEngine({
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final ArchiveAnalystConfidenceEngine confidenceEngine;
  final BeliefTimelineEngine timelineEngine;

  BeliefLifecycleView build({
    required List<JournalEntry> entries,
    required String? activeStatement,
    BeliefEvolutionState? evolution,
  }) {
    final active = activeStatement?.trim() ?? '';
    BeliefLifecycleEntry? current;
    if (active.isNotEmpty && !_isPlaceholder(active)) {
      current = _entryForStatement(
        statement: active,
        entries: entries,
        isActiveInArchive: true,
        evolution: evolution,
      );
    }

    final retired = <BeliefLifecycleEntry>[];
    if (evolution != null) {
      final seen = <String>{};
      if (active.isNotEmpty) seen.add(_normalize(active));

      for (final version in evolution.versions) {
        final text = version.beliefText.trim();
        if (text.isEmpty) continue;
        final norm = _normalize(text);
        if (!seen.add(norm)) continue;
        if (norm == _normalize(active)) continue;

        final entry = _entryForStatement(
          statement: text,
          entries: entries,
          isActiveInArchive: false,
          evolution: evolution,
          versionHint: version,
        );
        if (entry != null) retired.add(entry);
      }
    }

    retired.sort((a, b) {
      final aDate = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return BeliefLifecycleView(current: current, retired: retired);
  }

  BeliefLifecycleEntry? _entryForStatement({
    required String statement,
    required List<JournalEntry> entries,
    required bool isActiveInArchive,
    BeliefEvolutionState? evolution,
    BeliefVersionRecord? versionHint,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty) return null;

    final split = confidenceEngine.splitEntries(
      beliefText: statement,
      eligible: eligible,
    );

    final keywords = _keywordsFrom(statement);
    final mentionEntries = _mentionEntries(eligible, keywords);
    if (mentionEntries.isEmpty && !isActiveInArchive) return null;

    final firstSeen = mentionEntries.isNotEmpty
        ? mentionEntries.first.createdAt
        : _dateFromRecord(versionHint?.recordedAt);
    final lastSeen = mentionEntries.isNotEmpty
        ? mentionEntries.last.createdAt
        : _dateFromRecord(versionHint?.recordedAt);

    final timeline = timelineEngine.build(
      entries: entries,
      beliefText: statement,
    );

    final status = _resolveStatus(
      isActiveInArchive: isActiveInArchive,
      splitStale: split.stale,
      recentMentionCount: _recentMentionCount(mentionEntries, eligible),
      totalMentions: mentionEntries.length,
      timeline: timeline,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      eligible: eligible,
    );

    final events = _buildEvents(
      status: status,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      timeline: timeline,
      evolution: evolution,
      statement: statement,
      isActiveInArchive: isActiveInArchive,
    );

    return BeliefLifecycleEntry(
      statement: statement,
      status: status,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      isActiveInArchive: isActiveInArchive,
      events: events,
    );
  }

  BeliefLifecycleStatus _resolveStatus({
    required bool isActiveInArchive,
    required bool splitStale,
    required int recentMentionCount,
    required int totalMentions,
    required BeliefTimeline timeline,
    required DateTime? firstSeen,
    required DateTime? lastSeen,
    required List<JournalEntry> eligible,
  }) {
    if (!isActiveInArchive) {
      if (recentMentionCount == 0) {
        return BeliefLifecycleStatus.noLongerDetected;
      }
      if (splitStale) return BeliefLifecycleStatus.dormant;
      return BeliefLifecycleStatus.weakening;
    }

    if (totalMentions == 0) {
      return BeliefLifecycleStatus.emerging;
    }

    if (recentMentionCount == 0 && totalMentions > 0) {
      return BeliefLifecycleStatus.dormant;
    }

    if (timeline.trend == BeliefTimelineTrend.strengthening) {
      return BeliefLifecycleStatus.emerging;
    }
    if (timeline.trend == BeliefTimelineTrend.weakening) {
      return BeliefLifecycleStatus.weakening;
    }

    if (firstSeen != null && lastSeen != null && eligible.length >= 4) {
      final span = eligible.last.createdAt.difference(eligible.first.createdAt);
      if (span.inDays > 0) {
        final recentCutoff = eligible.last.createdAt.subtract(
          Duration(days: (span.inDays * 0.25).round().clamp(7, 90)),
        );
        if (firstSeen.isAfter(recentCutoff) && totalMentions <= 4) {
          return BeliefLifecycleStatus.emerging;
        }
      }
    }

    return BeliefLifecycleStatus.stable;
  }

  List<BeliefLifecycleEvent> _buildEvents({
    required BeliefLifecycleStatus status,
    required DateTime? firstSeen,
    required DateTime? lastSeen,
    required BeliefTimeline timeline,
    required BeliefEvolutionState? evolution,
    required String statement,
    required bool isActiveInArchive,
  }) {
    final events = <BeliefLifecycleEvent>[];
    if (firstSeen != null) {
      events.add(
        BeliefLifecycleEvent(
          phase: BeliefLifecyclePhase.firstAppearance,
          date: firstSeen,
          summary: BeliefLifecycleCopy.eventFirstAppearance,
        ),
      );
    }

    if (timeline.trend == BeliefTimelineTrend.strengthening &&
        lastSeen != null) {
      events.add(
        BeliefLifecycleEvent(
          phase: BeliefLifecyclePhase.strengthening,
          date: lastSeen,
          summary: BeliefLifecycleCopy.eventStrengthening,
        ),
      );
    } else if (timeline.trend == BeliefTimelineTrend.weakening &&
        lastSeen != null) {
      events.add(
        BeliefLifecycleEvent(
          phase: BeliefLifecyclePhase.weakening,
          date: lastSeen,
          summary: BeliefLifecycleCopy.eventWeakening,
        ),
      );
    }

    for (final pair in _evolutionTransitions(evolution)) {
      if (_normalize(pair.text) != _normalize(statement)) continue;
      if (pair.delta >= 8 && lastSeen != null) {
        events.add(
          BeliefLifecycleEvent(
            phase: BeliefLifecyclePhase.strengthening,
            date: _dateFromRecord(pair.recordedAt) ?? lastSeen,
            summary: BeliefLifecycleCopy.eventStrengthening,
          ),
        );
      } else if (pair.delta <= -8 && lastSeen != null) {
        events.add(
          BeliefLifecycleEvent(
            phase: BeliefLifecyclePhase.weakening,
            date: _dateFromRecord(pair.recordedAt) ?? lastSeen,
            summary: BeliefLifecycleCopy.eventWeakening,
          ),
        );
      }
    }

    if (status == BeliefLifecycleStatus.noLongerDetected && lastSeen != null) {
      events.add(
        BeliefLifecycleEvent(
          phase: BeliefLifecyclePhase.death,
          date: lastSeen,
          summary: BeliefLifecycleCopy.eventDeath,
        ),
      );
    } else if (!isActiveInArchive && lastSeen != null) {
      events.add(
        BeliefLifecycleEvent(
          phase: BeliefLifecyclePhase.death,
          date: lastSeen,
          summary: BeliefLifecycleCopy.eventDeath,
        ),
      );
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return _dedupeEvents(events);
  }

  List<BeliefLifecycleEvent> _dedupeEvents(List<BeliefLifecycleEvent> events) {
    final out = <BeliefLifecycleEvent>[];
    final seen = <String>{};
    for (final e in events) {
      final key = '${e.phase.name}|${e.date.toIso8601String()}';
      if (seen.add(key)) out.add(e);
    }
    return out;
  }

  List<_EvoTransition> _evolutionTransitions(BeliefEvolutionState? evolution) {
    if (evolution == null || evolution.versions.length < 2) return const [];
    final out = <_EvoTransition>[];
    for (var i = 1; i < evolution.versions.length; i++) {
      final prev = evolution.versions[i - 1];
      final next = evolution.versions[i];
      out.add(
        _EvoTransition(
          text: next.beliefText,
          recordedAt: next.recordedAt,
          delta: next.confidence - prev.confidence,
        ),
      );
    }
    return out;
  }

  List<JournalEntry> _mentionEntries(
    List<JournalEntry> eligible,
    Set<String> keywords,
  ) {
    if (keywords.isEmpty) return const [];
    final hits = <JournalEntry>[];
    for (final e in eligible) {
      if (_overlapScore(e.transcript, keywords) >= 1) {
        hits.add(e);
      }
    }
    return hits;
  }

  int _recentMentionCount(
    List<JournalEntry> mentions,
    List<JournalEntry> eligible,
  ) {
    if (mentions.isEmpty || eligible.isEmpty) return 0;
    final sorted = [...eligible]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final cutoffIndex = (sorted.length * 0.75).floor();
    final recentCutoff = sorted.length <= 1
        ? sorted.last.createdAt
        : sorted[cutoffIndex.clamp(0, sorted.length - 1)].createdAt;
    return mentions.where((e) => !e.createdAt.isBefore(recentCutoff)).length;
  }

  int _overlapScore(String transcript, Set<String> keywords) {
    final lower = transcript.toLowerCase();
    return keywords.where(lower.contains).length;
  }

  Set<String> _keywordsFrom(String belief) {
    return belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _isPlaceholder(String text) {
    final lower = text.toLowerCase();
    return lower.contains('still gathering evidence') ||
        lower.contains('working belief is forming');
  }

  DateTime? _dateFromRecord(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);
}

class _EvoTransition {
  const _EvoTransition({
    required this.text,
    required this.recordedAt,
    required this.delta,
  });

  final String text;
  final String recordedAt;
  final int delta;
}
