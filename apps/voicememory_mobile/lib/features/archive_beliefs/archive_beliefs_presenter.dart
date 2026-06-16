import '../../models/journal_entry.dart';
import '../archive_theory/theory_ranking_models.dart';
import '../archive_v1/archive_v1_models.dart';
import '../belief_lifecycle/belief_lifecycle_models.dart';
import '../discover/discover_local.dart';
import 'archive_belief_models.dart';

/// Maps journal + archive engines into belief cards the user can understand.
class ArchiveBeliefsPresenter {
  const ArchiveBeliefsPresenter._();

  static ArchiveBeliefsSnapshot build({
    required List<JournalEntry> entries,
    ArchiveV1View? archiveV1,
    DiscoverLocalFeed? discoverFeed,
  }) {
    final cards = <ArchiveBeliefCardModel>[];

    final ranking = archiveV1?.theoryRanking;
    if (ranking?.primaryTheory != null) {
      final t = ranking!.primaryTheory!;
      cards.add(_fromRanked(t, ArchiveBeliefSection.current));
    }
    for (final t in ranking?.secondaryTheories ?? const []) {
      cards.add(_fromRanked(t, ArchiveBeliefSection.emerging));
    }

    final lifecycle = archiveV1?.lifecycle;
    if (lifecycle?.current != null) {
      cards.add(
        _fromLifecycle(lifecycle!.current!, ArchiveBeliefSection.current),
      );
    }
    for (final r in lifecycle?.retired ?? const []) {
      final section =
          r.status == BeliefLifecycleStatus.weakening ||
              r.status == BeliefLifecycleStatus.dormant
          ? ArchiveBeliefSection.changing
          : ArchiveBeliefSection.emerging;
      cards.add(_fromLifecycle(r, section));
    }

    final belief = archiveV1?.belief;
    if (belief != null && !cards.any((c) => c.statement == belief.statement)) {
      cards.add(
        ArchiveBeliefCardModel(
          id: _idFor(belief.statement),
          statement: belief.statement,
          confidencePercent: belief.confidencePercent,
          evidenceSummary:
              'Appeared in ${belief.evidenceCount} reflection${belief.evidenceCount == 1 ? '' : 's'}.',
          whyExplanation:
              'Named from recurring themes across your reflections.',
          section: ArchiveBeliefSection.current,
          timeline: _timelineFromEntries(belief.supportingEntries),
          conclusion: 'This pattern appears consistently in what you record.',
        ),
      );
    }

    if (discoverFeed != null && discoverFeed.hasBaseline) {
      for (final item in discoverFeed.strengthened) {
        cards.add(_fromDiscover(item, ArchiveBeliefSection.changing));
      }
      for (final item in discoverFeed.newItems) {
        cards.add(_fromDiscover(item, ArchiveBeliefSection.emerging));
      }
    }

    for (final spot in archiveV1?.blindSpots ?? const []) {
      cards.add(
        ArchiveBeliefCardModel(
          id: 'blind-${spot.id}',
          statement: spot.headline,
          confidencePercent: spot.confidence.clamp(40, 90),
          evidenceSummary:
              'Observed across ${spot.evidenceCount} reflection${spot.evidenceCount == 1 ? '' : 's'}.',
          whyExplanation: spot.observation,
          section: ArchiveBeliefSection.hiddenPattern,
        ),
      );
    }

    _addThemePatterns(entries, cards);

    final deduped = _dedupe(cards);
    final sorted = [...deduped]
      ..sort((a, b) => b.confidencePercent.compareTo(a.confidencePercent));

    final current = sorted
        .where((c) => c.section == ArchiveBeliefSection.current)
        .toList();
    final emerging = sorted
        .where((c) => c.section == ArchiveBeliefSection.emerging)
        .toList();
    final changing = sorted
        .where((c) => c.section == ArchiveBeliefSection.changing)
        .toList();
    final hidden = sorted
        .where((c) => c.section == ArchiveBeliefSection.hiddenPattern)
        .toList();

    final home = sorted.take(3).toList();

    return ArchiveBeliefsSnapshot(
      homeBeliefs: home,
      current: current,
      emerging: emerging,
      changing: changing,
      hiddenPatterns: hidden,
      stats: _stats(entries, sorted),
    );
  }

  static ArchiveBeliefCardModel _fromRanked(
    RankedTheory t,
    ArchiveBeliefSection section,
  ) {
    return ArchiveBeliefCardModel(
      id: t.candidateId,
      statement: t.statement,
      confidencePercent: t.confidencePercent,
      evidenceSummary:
          'Appeared in ${t.evidenceCount} reflection${t.evidenceCount == 1 ? '' : 's'}.',
      whyExplanation:
          'ArchiveMe ranked this from recurring themes in your reflections.',
      section: section,
      timeline: _timelineFromEntries(t.supportingEntries),
      conclusion: 'This pattern has enough reflections to show up clearly.',
    );
  }

  static ArchiveBeliefCardModel _fromLifecycle(
    BeliefLifecycleEntry entry,
    ArchiveBeliefSection section,
  ) {
    final why = switch (entry.status) {
      BeliefLifecycleStatus.emerging =>
        'First detected recently across your reflections.',
      BeliefLifecycleStatus.stable =>
        'Has remained steady across your reflections over time.',
      BeliefLifecycleStatus.weakening =>
        'Shows up less often in recent reflections.',
      BeliefLifecycleStatus.dormant =>
        'Mentioned less often in recent recordings.',
      BeliefLifecycleStatus.noLongerDetected =>
        'No longer appears in recent reflections.',
    };
    return ArchiveBeliefCardModel(
      id: _idFor(entry.statement),
      statement: entry.statement,
      confidencePercent: _lifecycleConfidence(entry.status),
      evidenceSummary:
          'Tracked since ${_monthYear(entry.firstSeen)} in your reflections.',
      whyExplanation: why,
      section: section,
      timeline: entry.events
          .map(
            (e) => BeliefEvidenceQuote(
              periodLabel: _monthYear(e.date),
              quote: e.summary,
            ),
          )
          .toList(),
      conclusion: entry.isActiveInArchive
          ? 'Still active in what keeps showing up for you.'
          : 'May be fading from your current story.',
    );
  }

  static ArchiveBeliefCardModel _fromDiscover(
    DiscoverChangeItem item,
    ArchiveBeliefSection section,
  ) {
    return ArchiveBeliefCardModel(
      id: _idFor(item.title),
      statement: _titleCase(item.title),
      confidencePercent: section == ArchiveBeliefSection.emerging ? 62 : 68,
      evidenceSummary: 'Pattern shift detected in recent reflections.',
      whyExplanation: item.detail,
      section: section,
    );
  }

  static void _addThemePatterns(
    List<JournalEntry> entries,
    List<ArchiveBeliefCardModel> cards,
  ) {
    final counts = DiscoverLocalEngine.themeCounts(entries);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(2)) {
      if (e.value < 2) continue;
      final title = _titleCase(e.key);
      if (cards.any((c) => c.statement.toLowerCase().contains(e.key))) continue;
      cards.add(
        ArchiveBeliefCardModel(
          id: 'theme-${e.key}',
          statement: '$title is a recurring theme.',
          confidencePercent: (55 + e.value * 4).clamp(55, 75),
          evidenceSummary: 'Mentioned in ${e.value} recordings.',
          whyExplanation:
              'ArchiveMe noticed this topic repeating across months of reflections.',
          section: ArchiveBeliefSection.hiddenPattern,
        ),
      );
    }
  }

  static List<ArchiveBeliefCardModel> _dedupe(
    List<ArchiveBeliefCardModel> cards,
  ) {
    final seen = <String>{};
    final out = <ArchiveBeliefCardModel>[];
    for (final c in cards) {
      final key = c.statement.trim().toLowerCase();
      if (seen.add(key)) out.add(c);
    }
    return out;
  }

  static ArchiveBeliefStats _stats(
    List<JournalEntry> entries,
    List<ArchiveBeliefCardModel> beliefs,
  ) {
    final dates = entries.map((e) => e.createdAt).whereType<DateTime>().toList()
      ..sort();
    final ageDays = dates.isEmpty
        ? 0
        : DateTime.now().difference(dates.first).inDays.clamp(0, 9999);
    final strongest = beliefs.isEmpty ? null : beliefs.first.statement;
    var evidence = 0;
    for (final b in beliefs) {
      final m = RegExp(r'(\d+)').firstMatch(b.evidenceSummary);
      if (m != null) evidence += int.tryParse(m.group(1)!) ?? 0;
    }
    return ArchiveBeliefStats(
      beliefsIdentified: beliefs.length,
      strongestBelief: strongest,
      archiveAgeDays: ageDays,
      reflectionsAnalysed: entries.length,
      evidencePoints: evidence > 0 ? evidence : entries.length,
    );
  }

  static List<BeliefEvidenceQuote> _timelineFromEntries(
    List<JournalEntry> entries,
  ) {
    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.take(4).map((e) {
      final r = e.reflection;
      final text = r.concreteObservation.trim().isNotEmpty
          ? r.concreteObservation
          : (r.repeatedSignal.trim().isNotEmpty
                ? r.repeatedSignal
                : (e.transcript.trim().isNotEmpty
                      ? e.transcript
                      : 'Reflection captured.'));
      final quote = text.length > 120 ? '${text.substring(0, 117)}…' : text;
      return BeliefEvidenceQuote(
        periodLabel: _monthYear(e.createdAt),
        quote: '"$quote"',
      );
    }).toList();
  }

  static String _idFor(String statement) =>
      'belief-${statement.hashCode.abs()}';

  static int _lifecycleConfidence(BeliefLifecycleStatus status) =>
      switch (status) {
        BeliefLifecycleStatus.emerging => 58,
        BeliefLifecycleStatus.stable => 78,
        BeliefLifecycleStatus.weakening => 52,
        BeliefLifecycleStatus.dormant => 45,
        BeliefLifecycleStatus.noLongerDetected => 30,
      };

  static String _monthYear(DateTime? dt) {
    if (dt == null) return 'Recent';
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
    return months[dt.month - 1];
  }

  static String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Early signals after a new recording — themes from latest reflection.
  static List<String> potentialSignalsFromEntry(JournalEntry entry) {
    final themes = entry.reflection.recurringThemes;
    if (themes.isNotEmpty) {
      return themes.take(4).map(_titleCase).toList();
    }
    final obs = entry.reflection.concreteObservation.trim();
    if (obs.length > 12) {
      return [obs.length > 48 ? '${obs.substring(0, 45)}…' : obs];
    }
    return const [];
  }
}
