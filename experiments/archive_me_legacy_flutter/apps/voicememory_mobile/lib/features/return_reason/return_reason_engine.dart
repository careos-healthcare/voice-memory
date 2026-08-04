import '../../core/archive_intelligence/archive_intelligence_engine.dart';
import '../../models/journal_entry.dart';
import '../../design/warm_archive_copy.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../belief_change/belief_change_detector.dart';
import '../belief_change/belief_change_models.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../discover/discover_models.dart';
import '../discover/theme_engine.dart';
import 'return_reason_models.dart';

/// Builds honest “come back” reasons when the user leaves Discover.
class ReturnReasonEngine {
  const ReturnReasonEngine({
    this.intelligenceEngine = const ArchiveIntelligenceEngine(),
    this.beliefChangeDetector = const BeliefChangeDetector(),
  });

  final ArchiveIntelligenceEngine intelligenceEngine;
  final BeliefChangeDetector beliefChangeDetector;

  static const int maxUnresolvedPatterns = 3;
  static const int maxRecordingsNeeded = 3;
  static const int minRecordingsNeeded = 2;

  /// Produces a card + persisted state, or null when nothing genuine to say.
  ReturnReasonCard? build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (entries.isEmpty) return null;

    final eligible = archiveEligibleEvidenceEntries(entries);
    final snapshot = intelligenceEngine.buildDiscovery(
      entries: entries,
      state: state,
    );

    final pendingQuestions = _pendingQuestions(snapshot, state, eligible);
    final unresolvedPatterns = _unresolvedPatterns(snapshot, eligible);
    final emergingBeliefs = _emergingBeliefs(snapshot, entries, state);

    final contradiction = _topContradiction(entries, state, snapshot);
    if (contradiction != null) {
      final belief = _beliefInTension(contradiction, state);
      return ReturnReasonCard(
        kind: ReturnReasonKind.conflictingEvidence,
        leadLine: 'Keep recording.',
        bodyLines: const [
          'Your archive has conflicting evidence.',
          'It cannot yet determine whether:',
        ],
        beliefQuote: belief,
        state: ReturnReasonState(
          pendingQuestions: pendingQuestions,
          unresolvedPatterns: unresolvedPatterns,
          emergingBeliefs: emergingBeliefs,
          generatedAt: DateTime.now(),
          primaryMessage: 'Conflicting evidence',
          kind: ReturnReasonKind.conflictingEvidence.name,
          beliefFocus: belief,
        ),
      );
    }

    if (unresolvedPatterns.length >= 2) {
      final needed = _recordingsNeeded(eligible.length);
      return ReturnReasonCard(
        kind: ReturnReasonKind.uncertainPatterns,
        leadLine: 'Keep recording.',
        bodyLines: [
          'Your archive is currently uncertain about:',
          ...unresolvedPatterns.map((p) => '• $p'),
          '$needed more recordings may reveal a stronger pattern.',
        ],
        recordingsNeeded: needed,
        state: ReturnReasonState(
          pendingQuestions: pendingQuestions,
          unresolvedPatterns: unresolvedPatterns,
          emergingBeliefs: emergingBeliefs,
          generatedAt: DateTime.now(),
          primaryMessage: 'Uncertain about ${unresolvedPatterns.join(', ')}',
          kind: ReturnReasonKind.uncertainPatterns.name,
          recordingsNeeded: needed,
        ),
      );
    }

    if (emergingBeliefs.isNotEmpty) {
      final belief = emergingBeliefs.first;
      var prior = 7;
      var current = 48;
      for (final c in snapshot.beliefChanges) {
        if (c.beliefStatement == belief) {
          prior = c.priorPercent;
          current = c.currentPercent;
          break;
        }
      }
      return ReturnReasonCard(
        kind: ReturnReasonKind.emergingBelief,
        leadLine: 'Keep recording.',
        bodyLines: [
          'A new belief may be emerging.',
          WarmArchiveCopy.confidenceConcept,
          WarmArchiveCopy.confidenceShiftPhrase(prior: prior, current: current),
          'Continue recording.',
        ],
        beliefQuote: belief,
        state: ReturnReasonState(
          pendingQuestions: pendingQuestions,
          unresolvedPatterns: unresolvedPatterns,
          emergingBeliefs: emergingBeliefs,
          generatedAt: DateTime.now(),
          primaryMessage: 'Emerging belief',
          kind: ReturnReasonKind.emergingBelief.name,
          beliefFocus: belief,
        ),
      );
    }

    if (!archiveHasMinimumEvidence(entries)) {
      final needed = _recordingsNeeded(eligible.length);
      final patterns = unresolvedPatterns.isNotEmpty
          ? unresolvedPatterns
          : _earlyThemeNames(snapshot);
      if (patterns.isEmpty) return null;

      return ReturnReasonCard(
        kind: ReturnReasonKind.keepRecording,
        leadLine: 'Keep recording.',
        bodyLines: [
          'Your archive is still forming its first clear patterns.',
          'Your archive is currently uncertain about:',
          ...patterns.take(2).map((p) => '• $p'),
          '$needed more recordings may reveal a stronger pattern.',
        ],
        recordingsNeeded: needed,
        state: ReturnReasonState(
          pendingQuestions: pendingQuestions,
          unresolvedPatterns: patterns,
          emergingBeliefs: emergingBeliefs,
          generatedAt: DateTime.now(),
          primaryMessage: 'Archive still forming',
          kind: ReturnReasonKind.keepRecording.name,
          recordingsNeeded: needed,
        ),
      );
    }

    if (pendingQuestions.isNotEmpty &&
        state?.health == ArchiveHealthV3.uncertain) {
      return ReturnReasonCard(
        kind: ReturnReasonKind.uncertainPatterns,
        leadLine: 'Keep recording.',
        bodyLines: [
          'Your archive has open questions it cannot answer yet.',
          ...pendingQuestions.take(2).map((q) => '• $q'),
          'Continue recording.',
        ],
        state: ReturnReasonState(
          pendingQuestions: pendingQuestions,
          unresolvedPatterns: unresolvedPatterns,
          emergingBeliefs: emergingBeliefs,
          generatedAt: DateTime.now(),
          primaryMessage: pendingQuestions.first,
          kind: ReturnReasonKind.uncertainPatterns.name,
        ),
      );
    }

    return null;
  }

  List<String> _pendingQuestions(
    DiscoverYourselfSnapshot snapshot,
    ArchiveStateObjectV3? state,
    List<JournalEntry> eligible,
  ) {
    final out = <String>[];
    if (!archiveHasMinimumEvidence(eligible) && eligible.isNotEmpty) {
      out.add('What belief is the archive still too uncertain to name?');
    }
    if (state?.health == ArchiveHealthV3.uncertain) {
      out.add('Whether your current belief is stable or still shifting');
    }
    for (final c in snapshot.contradictions.take(1)) {
      out.add(
        'Whether “${_clip(c.statementA)}” or “${_clip(c.statementB)}” reflects you more now',
      );
    }
    return out;
  }

  List<String> _unresolvedPatterns(
    DiscoverYourselfSnapshot snapshot,
    List<JournalEntry> eligible,
  ) {
    final out = <String>[];

    for (final t in snapshot.themes) {
      if (t.frequency >= 4) continue;
      if (t.frequency >= 1) out.add(t.name);
    }

    if (out.length < 2) {
      final counts = DiscoverLocalThemeCounts.count(eligible);
      for (final e in counts.entries) {
        if (e.value >= 1 && e.value <= 3) {
          final name = _themeDisplayName(e.key);
          if (!out.contains(name)) out.add(name);
        }
      }
    }

    return out.take(maxUnresolvedPatterns).toList();
  }

  List<String> _emergingBeliefs(
    DiscoverYourselfSnapshot snapshot,
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final out = <String>[];

    for (final c in snapshot.beliefChanges) {
      if (c.type == BeliefChangeAlertType.newBeliefEmerging.name ||
          c.type == BeliefChangeAlertType.confidenceIncrease.name) {
        out.add(c.beliefStatement);
      }
    }

    final alerts = beliefChangeDetector.detect(entries: entries, state: state);
    for (final a in alerts) {
      if (a.type == BeliefChangeAlertType.newBeliefEmerging &&
          !out.contains(a.beliefStatement)) {
        out.add(a.beliefStatement);
      }
    }

    if (out.isEmpty &&
        snapshot.belief != null &&
        snapshot.belief!.confidencePercent < 55) {
      final stmt = snapshot.belief!.statement;
      if (stmt.length >= 12 && !stmt.contains('still gathering')) {
        out.add(stmt);
      }
    }

    return out.take(2).toList();
  }

  DiscoverContradictionInsight? _topContradiction(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DiscoverYourselfSnapshot snapshot,
  ) {
    if (snapshot.contradictions.isNotEmpty) {
      return snapshot.contradictions.first;
    }

    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: state?.belief,
    );
    if (result.reports.isEmpty) return null;

    final r = result.reports.first;
    final byId = {for (final e in entries) e.id: e};
    return DiscoverContradictionInsight(
      statementA: r.originalStatement,
      statementB: r.conflictingStatement,
      dateA: byId[r.originalEntryId]?.createdAt ?? DateTime.now(),
      dateB: byId[r.conflictingEntryId]?.createdAt ?? DateTime.now(),
      confidenceScore: r.confidenceScore,
      entryIdA: r.originalEntryId,
      entryIdB: r.conflictingEntryId,
    );
  }

  static String _beliefInTension(
    DiscoverContradictionInsight c,
    ArchiveStateObjectV3? state,
  ) {
    final belief = state?.belief?.trim();
    if (belief != null && belief.isNotEmpty) {
      return belief.length > 100 ? '${belief.substring(0, 100)}…' : belief;
    }
    return _clip(c.statementA);
  }

  static List<String> _earlyThemeNames(DiscoverYourselfSnapshot snapshot) {
    return snapshot.themes.take(2).map((t) => t.name).toList();
  }

  static int _recordingsNeeded(int eligibleCount) {
    final need = archiveMinEvidenceReflections - eligibleCount;
    if (need <= 0) return minRecordingsNeeded;
    return need.clamp(minRecordingsNeeded, maxRecordingsNeeded);
  }

  static String _themeDisplayName(String key) {
    const labels = {
      'career': 'Career',
      'work': 'Work',
      'confidence': 'Confidence',
      'relationship': 'Relationships',
      'relationships': 'Relationships',
      'health': 'Health',
      'family': 'Family',
      'stress': 'Stress',
      'money': 'Money',
      'purpose': 'Purpose',
    };
    return labels[key] ??
        (key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}');
  }

  static String _clip(String text) {
    final t = text.trim();
    if (t.length <= 72) return t;
    return '${t.substring(0, 72)}…';
  }
}
