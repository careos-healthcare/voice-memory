import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/comparison/comparison_models.dart';
import 'package:archiveme_mobile/features/evidence_artifact/domain/evidence_proof_calculator.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Queries fact-ledger history and belief evolution for temporal state deltas.
abstract final class ComparisonEngineService {
  ComparisonEngineService._();

  static ComparisonExplorerResult build({
    required ComparisonTemporalRange range,
    required List<JournalEntry> entries,
    required List<ArchiveFact> facts,
    required BeliefEvolutionState beliefEvolution,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(
      entries,
      analyticsSource: 'comparison_engine',
    );

    final windows = _resolveWindows(range, eligible, anchor);
    final thenEntries = _entriesInWindow(
      eligible,
      windows.thenStart,
      windows.thenEnd,
      inclusiveEnd: false,
    );
    final nowEntries = _entriesInWindow(
      eligible,
      windows.nowStart,
      windows.nowEnd,
    );

    final thenFacts = _factsInWindow(
      facts,
      windows.thenStart,
      windows.thenEnd,
      inclusiveEnd: false,
    );
    final nowFacts = _factsInWindow(
      facts,
      windows.nowStart,
      windows.nowEnd,
    );

    final thenBelief = _beliefForPeriod(
      beliefEvolution: beliefEvolution,
      entries: thenEntries,
      periodEnd: windows.thenEnd,
      fallback: _beliefFromEntries(thenEntries),
    );
    final nowBelief = _beliefForPeriod(
      beliefEvolution: beliefEvolution,
      entries: nowEntries,
      periodEnd: windows.nowEnd,
      fallback: _beliefFromEntries(nowEntries),
    );

    final thenBand = EvidenceProofCalculator.bandFromConfidencePercent(
      thenBelief.confidence,
    );
    final nowBand = EvidenceProofCalculator.bandFromConfidencePercent(
      nowBelief.confidence,
    );

    final thenSnapshot = ComparisonPeriodSnapshot(
      label: range.thenDescription,
      beliefText: thenBelief.text,
      confidencePercent: thenBelief.confidence,
      confidenceBand: thenBand,
      citations: _citationsFor(thenEntries, thenFacts),
      factCount: thenFacts.length,
      entryCount: thenEntries.length,
      periodStart: windows.thenStart,
      periodEnd: windows.thenEnd,
    );

    final nowSnapshot = ComparisonPeriodSnapshot(
      label: range.nowDescription,
      beliefText: nowBelief.text,
      confidencePercent: nowBelief.confidence,
      confidenceBand: nowBand,
      citations: _citationsFor(nowEntries, nowFacts),
      factCount: nowFacts.length,
      entryCount: nowEntries.length,
      periodStart: windows.nowStart,
      periodEnd: windows.nowEnd,
    );

    final dropped = _droppedAssumptions(thenEntries, nowEntries);
    final shifts = _computeShifts(
      range: range,
      then: thenSnapshot,
      now: nowSnapshot,
      droppedAssumptions: dropped,
      contradictions: _recurringContradictions(thenEntries, nowEntries),
    );

    return ComparisonExplorerResult(
      range: range,
      then: thenSnapshot,
      now: nowSnapshot,
      shifts: shifts,
      droppedAssumptions: dropped,
      hasEnoughEvidence: thenEntries.isNotEmpty && nowEntries.isNotEmpty,
    );
  }

  static _ComparisonWindows _resolveWindows(
    ComparisonTemporalRange range,
    List<JournalEntry> eligible,
    DateTime anchor,
  ) {
    if (range == ComparisonTemporalRange.multiYearShift) {
      if (eligible.length < 2) {
        final end = anchor;
        return _ComparisonWindows(
          thenStart: end.subtract(const Duration(days: 1)),
          thenEnd: end,
          nowStart: end,
          nowEnd: end,
        );
      }
      final sorted = List<JournalEntry>.from(eligible)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final midpoint = sorted[sorted.length ~/ 2].createdAt;
      return _ComparisonWindows(
        thenStart: sorted.first.createdAt,
        thenEnd: midpoint,
        nowStart: midpoint,
        nowEnd: sorted.last.createdAt,
      );
    }

    final currentDays = range.currentDaysBack!;
    final baselineDays = range.baselineDaysBack!;
    final nowEnd = anchor;
    final nowStart = anchor.subtract(Duration(days: currentDays));
    final thenEnd = nowStart;
    final thenStart = anchor.subtract(Duration(days: baselineDays));

    return _ComparisonWindows(
      thenStart: thenStart,
      thenEnd: thenEnd,
      nowStart: nowStart,
      nowEnd: nowEnd,
    );
  }

  static List<JournalEntry> _entriesInWindow(
    List<JournalEntry> entries,
    DateTime start,
    DateTime end, {
    bool inclusiveEnd = true,
  }) {
    return entries
        .where(
          (entry) {
            if (entry.createdAt.isBefore(start)) return false;
            if (inclusiveEnd) return !entry.createdAt.isAfter(end);
            return entry.createdAt.isBefore(end);
          },
        )
        .toList(growable: false);
  }

  static List<ArchiveFact> _factsInWindow(
    List<ArchiveFact> facts,
    DateTime start,
    DateTime end, {
    bool inclusiveEnd = true,
  }) {
    return facts
        .where(
          (fact) {
            if (fact.createdAt.isBefore(start)) return false;
            if (inclusiveEnd) return !fact.createdAt.isAfter(end);
            return fact.createdAt.isBefore(end);
          },
        )
        .toList(growable: false);
  }

  static _BeliefAtPeriod _beliefForPeriod({
    required BeliefEvolutionState beliefEvolution,
    required List<JournalEntry> entries,
    required DateTime periodEnd,
    required String fallback,
  }) {
    BeliefVersionRecord? match;
    for (final version in beliefEvolution.versions) {
      final at = DateTime.tryParse(version.recordedAt);
      if (at == null || at.isAfter(periodEnd)) continue;
      if (match == null ||
          at.isAfter(DateTime.tryParse(match.recordedAt) ?? DateTime(1970))) {
        match = version;
      }
    }

    if (match != null) {
      return _BeliefAtPeriod(
        text: match.beliefText,
        confidence: match.confidence,
      );
    }

    return _BeliefAtPeriod(
      text: fallback,
      confidence: _confidenceFromEntryCount(entries.length),
    );
  }

  static String _beliefFromEntries(List<JournalEntry> entries) {
    if (entries.isEmpty) return '';
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final entry in sorted) {
      final obs = entry.reflection.concreteObservation.trim();
      if (obs.length >= 12) return obs;
      final transcript = entry.transcript.trim();
      if (transcript.length >= 12) {
        return transcript.length <= 200
            ? transcript
            : '${transcript.substring(0, 200).trim()}…';
      }
    }
    return sorted.first.transcript.trim();
  }

  static int _confidenceFromEntryCount(int count) {
    if (count >= 8) return 85;
    if (count >= 4) return 72;
    if (count >= 2) return 55;
    if (count >= 1) return 35;
    return 0;
  }

  static List<ComparisonCitation> _citationsFor(
    List<JournalEntry> entries,
    List<ArchiveFact> facts,
  ) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final citations = <ComparisonCitation>[];

    for (final entry in sorted.take(6)) {
      citations.add(
        ComparisonCitation(
          entryId: entry.id,
          quote: _quoteForEntry(entry),
          recordedAt: entry.createdAt,
        ),
      );
    }

    for (final fact in facts.take(4)) {
      if (citations.any((c) => c.entryId == fact.sourceEntryId)) continue;
      citations.add(
        ComparisonCitation(
          entryId: fact.sourceEntryId,
          quote: '"${fact.label}: ${fact.value}"',
          recordedAt: fact.createdAt,
          factLabel: fact.label,
        ),
      );
    }

    citations.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return citations;
  }

  static String _quoteForEntry(JournalEntry entry) {
    final exact = entry.reflection.exactLanguagePattern.trim();
    if (exact.length >= 12) {
      return exact.startsWith('"') ? exact : '"$exact"';
    }
    final transcript = entry.transcript.trim();
    if (transcript.isEmpty) {
      final obs = entry.reflection.concreteObservation.trim();
      return obs.isEmpty ? '(No transcript)' : '"$obs"';
    }
    final line = transcript.length <= 160
        ? transcript
        : '${transcript.substring(0, 160).trim()}…';
    return '"$line"';
  }

  static List<String> _droppedAssumptions(
    List<JournalEntry> thenEntries,
    List<JournalEntry> nowEntries,
  ) {
    final thenThemes = _themeSet(thenEntries);
    final nowThemes = _themeSet(nowEntries);
    return thenThemes.difference(nowThemes).take(4).toList(growable: false);
  }

  static Set<String> _themeSet(List<JournalEntry> entries) {
    final themes = <String>{};
    for (final entry in entries) {
      for (final raw in entry.reflection.recurringThemes) {
        final theme = raw.trim().toLowerCase();
        if (theme.isNotEmpty) themes.add(theme);
      }
    }
    return themes;
  }

  static List<String> _recurringContradictions(
    List<JournalEntry> thenEntries,
    List<JournalEntry> nowEntries,
  ) {
    final shared = _themeSet(thenEntries).intersection(_themeSet(nowEntries));
    if (shared.isEmpty) return const [];

    final contradictions = <String>[];
    for (final theme in shared) {
      final thenMoods = _moodsForTheme(thenEntries, theme);
      final nowMoods = _moodsForTheme(nowEntries, theme);
      if (thenMoods.isEmpty || nowMoods.isEmpty) continue;
      if (thenMoods.first != nowMoods.first) {
        contradictions.add(
          'Your tone around "$theme" shifted from ${thenMoods.first} to ${nowMoods.first}.',
        );
      }
    }
    return contradictions.take(3).toList(growable: false);
  }

  static List<String> _moodsForTheme(List<JournalEntry> entries, String theme) {
    final moods = <String>[];
    for (final entry in entries) {
      if (!entry.reflection.recurringThemes
          .map((t) => t.trim().toLowerCase())
          .contains(theme)) {
        continue;
      }
      final mood = entry.reflection.mood.trim().toLowerCase();
      if (mood.isNotEmpty) moods.add(mood);
    }
    return moods;
  }

  static List<ComparisonBeliefShift> _computeShifts({
    required ComparisonTemporalRange range,
    required ComparisonPeriodSnapshot then,
    required ComparisonPeriodSnapshot now,
    required List<String> droppedAssumptions,
    required List<String> contradictions,
  }) {
    final shifts = <ComparisonBeliefShift>[];
    final spanMonths = now.periodEnd.difference(then.periodStart).inDays ~/ 30;
    final spanLabel = spanMonths >= 12
        ? '${spanMonths ~/ 12} ${spanMonths ~/ 12 == 1 ? 'year' : 'years'}'
        : '$spanMonths ${spanMonths == 1 ? 'month' : 'months'}';

    if (then.hasBelief && now.hasBelief) {
      final normalizedThen = _normalize(then.beliefText);
      final normalizedNow = _normalize(now.beliefText);
      final confidenceDelta = now.confidencePercent - then.confidencePercent;
      final deltaBand = EvidenceProofCalculator.resolveBand(
        confidencePercent: now.confidencePercent,
        citationCount: then.entryCount + now.entryCount,
      );

      ComparisonShiftKind kind;
      String headline;
      if (normalizedThen == normalizedNow) {
        kind = confidenceDelta >= 10
            ? ComparisonShiftKind.strengthened
            : ComparisonShiftKind.weakened;
        headline = confidenceDelta >= 10
            ? 'This belief held steady and gained evidence'
            : 'This belief held steady with lighter overlap';
      } else if (normalizedNow.contains(normalizedThen) ||
          normalizedThen.contains(normalizedNow)) {
        kind = ComparisonShiftKind.strengthened;
        headline = 'Your wording evolved while the thread stayed recognizable';
      } else {
        kind = ComparisonShiftKind.emerged;
        headline = 'What you express now reads differently from your baseline';
      }

      shifts.add(
        ComparisonBeliefShift(
          kind: kind,
          headline: headline,
          thenBelief: then.beliefText,
          nowBelief: now.beliefText,
          deltaBand: deltaBand,
          deltaBadgeLabel: _deltaBadgeLabel(deltaBand, spanLabel),
          thenCitations: then.citations,
          nowCitations: now.citations,
        ),
      );
    } else if (now.hasBelief) {
      shifts.add(
        ComparisonBeliefShift(
          kind: ComparisonShiftKind.emerged,
          headline: 'A clearer belief thread appears in your recent archive',
          thenBelief: then.beliefText.isEmpty
              ? 'Not enough saved detail in the baseline window.'
              : then.beliefText,
          nowBelief: now.beliefText,
          deltaBand: now.confidenceBand,
          deltaBadgeLabel: _deltaBadgeLabel(now.confidenceBand, spanLabel),
          thenCitations: then.citations,
          nowCitations: now.citations,
        ),
      );
    }

    for (final assumption in droppedAssumptions) {
      shifts.add(
        ComparisonBeliefShift(
          kind: ComparisonShiftKind.dropped,
          headline: 'Assumption faded: "$assumption"',
          thenBelief: 'This theme appeared in your earlier window.',
          nowBelief: 'It has not returned in the current window.',
          deltaBand: PatternMatchConfidenceBand.emerging,
          deltaBadgeLabel: 'Dropped over $spanLabel',
          thenCitations: then.citations,
          nowCitations: now.citations,
        ),
      );
    }

    for (final contradiction in contradictions) {
      shifts.add(
        ComparisonBeliefShift(
          kind: ComparisonShiftKind.recurringContradiction,
          headline: 'Recurring tension surfaced across both windows',
          thenBelief: then.beliefText,
          nowBelief: now.beliefText,
          deltaBand: PatternMatchConfidenceBand.solid,
          deltaBadgeLabel: 'Contradiction tracked over $spanLabel',
          thenCitations: then.citations,
          nowCitations: now.citations,
          contradictionNote: contradiction,
        ),
      );
    }

    if (shifts.isEmpty && range == ComparisonTemporalRange.multiYearShift) {
      shifts.add(
        ComparisonBeliefShift(
          kind: ComparisonShiftKind.weakened,
          headline: 'Archive span captured, but belief overlap is still thin',
          thenBelief: then.beliefText,
          nowBelief: now.beliefText,
          deltaBand: PatternMatchConfidenceBand.weak,
          deltaBadgeLabel: 'Watching across $spanLabel',
          thenCitations: then.citations,
          nowCitations: now.citations,
        ),
      );
    }

    return shifts;
  }

  static String _deltaBadgeLabel(
    PatternMatchConfidenceBand band,
    String spanLabel,
  ) {
    final bandLabel = switch (band) {
      PatternMatchConfidenceBand.weak => 'Emerging',
      PatternMatchConfidenceBand.emerging => 'Emerging',
      PatternMatchConfidenceBand.solid => 'Solid',
      PatternMatchConfidenceBand.strong => 'Strong',
    };
    return 'Shift $bandLabel over $spanLabel';
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _ComparisonWindows {
  const _ComparisonWindows({
    required this.thenStart,
    required this.thenEnd,
    required this.nowStart,
    required this.nowEnd,
  });

  final DateTime thenStart;
  final DateTime thenEnd;
  final DateTime nowStart;
  final DateTime nowEnd;
}

class _BeliefAtPeriod {
  const _BeliefAtPeriod({required this.text, required this.confidence});

  final String text;
  final int confidence;
}