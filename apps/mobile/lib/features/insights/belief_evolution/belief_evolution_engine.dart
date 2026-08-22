import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/contradiction_detection/statement_analysis.dart';
import 'package:archiveme_mobile/features/discover/discover_local.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_citation_service.dart';
import 'package:archiveme_mobile/features/insights/belief_evolution/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/insights/insight_evidence.dart';
import 'package:archiveme_mobile/features/insights/insight_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Tracks belief themes over time using mention counts — no sentiment labels.
class BeliefEvolutionInsightEngine {
  const BeliefEvolutionInsightEngine({
    this.minSupportingReferences = InsightQualityRules.minEvidenceCount,
  });

  final int minSupportingReferences;

  List<BeliefEvolutionInsight> build({
    required List<JournalEntry> entries,
    DiscoverLocalFeed? discoverFeed,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minSupportingReferences) return const [];

    final mid = eligible.length ~/ 2;
    final firstHalf = eligible.sublist(0, mid.clamp(1, eligible.length));
    final secondHalf = eligible.sublist(mid.clamp(0, eligible.length - 1));

    final themes = _themeMentionSeries(eligible, firstHalf, secondHalf);
    final insights = <BeliefEvolutionInsight>[];

    for (final t in themes.entries) {
      final insight = _evolutionForTheme(t.key, t.value, eligible);
      if (insight != null) insights.add(insight);
    }

    if (discoverFeed != null && discoverFeed.hasBaseline) {
      for (final item in discoverFeed.strengthened) {
        insights.add(
          _fromFeedItem(
            id: 'evo-strong-${item.title}',
            statement: _titleCase(item.title),
            direction: BeliefEvolutionDirection.strengthening,
            summary: 'This may be changing — mentions of this pattern appear more often in recent entries.',
            detail: item.detail,
            entries: eligible,
          ),
        );
      }
      for (final item in discoverFeed.weakened) {
        insights.add(
          _fromFeedItem(
            id: 'evo-weak-${item.title}',
            statement: _titleCase(item.title),
            direction: BeliefEvolutionDirection.weakening,
            summary: 'This may be changing — mentions of this pattern appear less often recently.',
            detail: item.detail,
            entries: eligible,
          ),
        );
      }
      for (final item in discoverFeed.newItems) {
        insights.add(
          _fromFeedItem(
            id: 'evo-new-${item.title}',
            statement: _titleCase(item.title),
            direction: BeliefEvolutionDirection.emerging,
            summary: 'Your archive noticed a pattern that may be emerging in recent entries.',
            detail: item.detail,
            entries: eligible,
          ),
        );
      }
    }

    insights.sort((a, b) => b.confidence.compareTo(a.confidence));
    final seen = <String>{};
    return insights
        .where((i) => seen.add(i.statement.toLowerCase()))
        .take(8)
        .toList();
  }

  Map<String, _ThemeSeries> _themeMentionSeries(
    List<JournalEntry> all,
    List<JournalEntry> first,
    List<JournalEntry> second,
  ) {
    final map = <String, _ThemeSeries>{};
    void count(List<JournalEntry> slice, bool isFirst) {
      for (final e in slice) {
        for (final theme in e.reflection.recurringThemes) {
          final k = theme.trim().toLowerCase();
          if (k.isEmpty) continue;
          map.putIfAbsent(k, _ThemeSeries.new).add(isFirst);
        }
        for (final text in archiveStatementTexts(e)) {
          for (final kw in extractTopicKeywords(text.toLowerCase())) {
            map.putIfAbsent(kw, _ThemeSeries.new).add(isFirst);
          }
        }
      }
    }

    count(first, true);
    count(second, false);
    return map;
  }

  BeliefEvolutionInsight? _evolutionForTheme(
    String theme,
    _ThemeSeries series,
    List<JournalEntry> eligible,
  ) {
    final total = series.firstHalf + series.secondHalf;
    if (total < minSupportingReferences) return null;

    BeliefEvolutionDirection? direction;
    if (series.firstHalf == 0 && series.secondHalf >= minSupportingReferences) {
      direction = BeliefEvolutionDirection.emerging;
    } else if (series.secondHalf == 0 &&
        series.firstHalf >= minSupportingReferences) {
      direction = BeliefEvolutionDirection.disappearing;
    } else if (series.secondHalf >= series.firstHalf + 2 &&
        series.secondHalf > series.firstHalf) {
      direction = BeliefEvolutionDirection.strengthening;
    } else if (series.firstHalf >= series.secondHalf + 2 &&
        series.firstHalf > series.secondHalf) {
      direction = BeliefEvolutionDirection.weakening;
    } else {
      return null;
    }

    final statement =
        'Your archive noticed themes around $theme in several reflections.';
    final evidence = _evidenceForTheme(theme, eligible);
    if (evidence.length < minSupportingReferences) return null;

    final summary = switch (direction) {
      BeliefEvolutionDirection.strengthening =>
        'This may be changing — mentions of this pattern appear more often in recent entries.',
      BeliefEvolutionDirection.weakening =>
        'This may be changing — mentions of this pattern appear less often recently.',
      BeliefEvolutionDirection.emerging =>
        'Your archive noticed a pattern that may be emerging in recent entries.',
      BeliefEvolutionDirection.disappearing =>
        'Based on these entries, this pattern has stopped appearing in recent reflections.',
    };

    final dates = evidence.map((e) => e.recordedAt).toList()..sort();
    final record = TrackedBeliefRecord(
      beliefId: 'belief-theme-$theme',
      statement: statement,
      firstSeen: dates.first,
      lastSeen: dates.last,
      evidenceCount: evidence.length,
      confidenceHistory: [
        BeliefConfidencePoint(
          at: dates.first,
          confidence: 50 + series.firstHalf * 8,
          evidenceCount: series.firstHalf,
        ),
        BeliefConfidencePoint(
          at: dates.last,
          confidence: 50 + series.secondHalf * 8,
          evidenceCount: series.secondHalf,
        ),
      ],
      supportingReflectionIds: evidence.map((e) => e.entryId).toSet().toList(),
    );

    return BeliefEvolutionInsight(
      id: 'evo-$theme-${direction.name}',
      beliefId: record.beliefId,
      statement: statement,
      direction: direction,
      summary: summary,
      confidence: (55 + total * 5).clamp(55, 90),
      evidenceCount: evidence.length,
      supportingEvidence: evidence,
      record: record,
    );
  }

  List<InsightEvidenceLine> _evidenceForTheme(
    String theme,
    List<JournalEntry> entries,
  ) {
    final lines = <InsightEvidenceLine>[];
    for (final e in entries) {
      final blob = '${e.transcript} ${e.reflection.concreteObservation}'
          .toLowerCase();
      if (!blob.contains(theme) &&
          !e.reflection.recurringThemes
              .map((t) => t.toLowerCase())
              .contains(theme)) {
        continue;
      }
      final rawQuote = archiveQuotableStatementText(e) ?? '';
      final quote = FactLedgerCitationService.resolve(
        entryId: e.id,
        fallback: rawQuote,
      );
      lines.add(
        InsightEvidenceLine(
          entryId: e.id,
          quote: quote,
          recordedAt: e.createdAt,
        ),
      );
      if (lines.length >= 6) break;
    }
    return lines;
  }

  BeliefEvolutionInsight _fromFeedItem({
    required String id,
    required String statement,
    required BeliefEvolutionDirection direction,
    required String summary,
    required String detail,
    required List<JournalEntry> entries,
  }) {
    final evidence = entries
        .take(4)
        .map(
          (e) {
            final rawQuote = archiveQuotableStatementText(e) ?? '';
            return InsightEvidenceLine(
              entryId: e.id,
              quote: FactLedgerCitationService.resolve(
                entryId: e.id,
                fallback: rawQuote,
              ),
              recordedAt: e.createdAt,
            );
          },
        )
        .toList();
    final dates = evidence.map((e) => e.recordedAt).toList()..sort();
    final record = TrackedBeliefRecord(
      beliefId: id,
      statement: statement,
      firstSeen: dates.first,
      lastSeen: dates.last,
      evidenceCount: evidence.length,
      confidenceHistory: const [],
      supportingReflectionIds: evidence.map((e) => e.entryId).toList(),
    );
    return BeliefEvolutionInsight(
      id: id,
      beliefId: id,
      statement: statement,
      direction: direction,
      summary: summary,
      confidence: 62,
      evidenceCount: evidence.length,
      supportingEvidence: evidence,
      record: record,
    );
  }

  String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _ThemeSeries {
  int firstHalf = 0;
  int secondHalf = 0;
  void add(bool isFirst) => isFirst ? firstHalf++ : secondHalf++;
}