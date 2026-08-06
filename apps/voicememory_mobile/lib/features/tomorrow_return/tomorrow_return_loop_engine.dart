import '../../features/archive_beliefs/archive_belief_models.dart';
import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/daily_discoveries/daily_discovery_models.dart';
import '../../features/discover/discover_local.dart';
import '../../features/insights/archive_insight.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../../product/consumer_ui_copy.dart';
import 'tomorrow_return_loop_models.dart';

/// Builds the three return-loop answers from journal + local pattern signals.
class TomorrowReturnLoopEngine {
  const TomorrowReturnLoopEngine();

  TomorrowReturnLoop build({
    required List<JournalEntry> entries,
    DailyDiscovery? immediateDiscovery,
    DiscoverLocalFeed? discoverFeed,
    ArchiveBeliefsSnapshot? beliefs,
    ArchiveInsightsSnapshot? insights,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = _entriesOnDay(entries, clock);
    final latest = entries.isEmpty
        ? null
        : ([
            ...entries,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).first;

    final noticedToday = _noticedToday(
      today: today,
      latest: latest,
      immediateDiscovery: immediateDiscovery,
      discoverFeed: discoverFeed,
      beliefs: beliefs,
      insights: insights,
    );
    final comeBackTomorrow = _comeBackTomorrow(
      entries: entries,
      today: today,
      discoverFeed: discoverFeed,
      beliefs: beliefs,
      insights: insights,
    );
    final watchForNextTime = _watchForNextTime(
      latest: latest,
      discoverFeed: discoverFeed,
      beliefs: beliefs,
      insights: insights,
    );
    final watchForChips = _watchForChips(
      latest: latest,
      discoverFeed: discoverFeed,
      beliefs: beliefs,
      insights: insights,
      watchForNextTime: watchForNextTime,
    );

    return TomorrowReturnLoop(
      noticedToday: noticedToday,
      comeBackTomorrow: comeBackTomorrow,
      watchForNextTime: watchForNextTime,
      generatedAt: clock,
      watchForChips: watchForChips,
      tomorrowPrompt: ConsumerUiCopy.tomorrowNoticePrompt,
    );
  }

  String _noticedToday({
    required List<JournalEntry> today,
    required JournalEntry? latest,
    required DailyDiscovery? immediateDiscovery,
    required DiscoverLocalFeed? discoverFeed,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveInsightsSnapshot? insights,
  }) {
    if (immediateDiscovery != null) {
      final title = immediateDiscovery.title.trim();
      final summary = immediateDiscovery.summary.trim();
      if (title.isNotEmpty && summary.isNotEmpty) {
        return '$title $summary';
      }
      if (summary.isNotEmpty) return summary;
      if (title.isNotEmpty) return title;
    }

    if (discoverFeed != null && discoverFeed.strengthened.isNotEmpty) {
      final item = discoverFeed.strengthened.first;
      return '${_titleCase(item.title)} may be showing up more often. '
          '${item.detail}';
    }

    if (discoverFeed != null && discoverFeed.newItems.isNotEmpty) {
      final item = discoverFeed.newItems.first;
      return 'A pattern around ${_titleCase(item.title)} may be forming. '
          '${item.detail}';
    }

    final contradiction = insights?.contradictions.firstOrNull;
    if (contradiction != null) {
      return contradiction.summary.trim().isNotEmpty
          ? contradiction.summary
          : contradiction.title;
    }

    final strongest =
        beliefs?.current.firstOrNull ?? beliefs?.homeBeliefs.firstOrNull;
    if (strongest != null && today.isNotEmpty) {
      return 'Today connects with a pattern you keep mentioning: '
          '${_clip(strongest.statement, 120)}';
    }

    if (latest != null) {
      final line = _entryHighlight(latest);
      if (line != null) {
        return today.length > 1
            ? 'Across ${today.length} moments today, this stood out: $line'
            : 'From your latest moment: $line';
      }
    }

    return ConsumerUiCopy.savedPrivatelyOnDevice;
  }

  String _comeBackTomorrow({
    required List<JournalEntry> entries,
    required List<JournalEntry> today,
    required DiscoverLocalFeed? discoverFeed,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveInsightsSnapshot? insights,
  }) {
    if (discoverFeed != null && discoverFeed.newItems.isNotEmpty) {
      final theme = _titleCase(discoverFeed.newItems.first.title);
      return 'After one or two more reflections, ArchiveMe can tell if '
          '$theme is becoming a steady pattern — check back tomorrow.';
    }

    if (insights != null && insights.contradictions.isNotEmpty) {
      return 'Tomorrow you can see whether those two pulls feel different '
          'after you name another moment.';
    }

    if (discoverFeed != null && discoverFeed.weakened.isNotEmpty) {
      return 'A pattern may be easing. Tomorrow shows whether it stays quiet '
          'or comes back.';
    }

    final eligible = archiveEvidenceReflectionCount(entries);
    if (eligible < archiveMinEvidenceReflections) {
      final need = (archiveMinEvidenceReflections - eligible).clamp(1, 3);
      return 'Patterns sharpen quickly at first. '
          '$need more moment${need == 1 ? '' : 's'} this week, then check '
          'Patterns tomorrow.';
    }

    if (beliefs != null && beliefs.changing.isNotEmpty) {
      return 'Something is shifting in your reflections. Tomorrow’s Patterns '
          'view shows whether it strengthened or faded.';
    }

    if (today.length >= 2) {
      return 'You added more than one moment today. Tomorrow, Patterns will '
          'show what stayed consistent across them.';
    }

    return 'Each reflection updates your patterns. A quick visit tomorrow '
        'shows what changed overnight.';
  }

  String _watchForNextTime({
    required JournalEntry? latest,
    required DiscoverLocalFeed? discoverFeed,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveInsightsSnapshot? insights,
  }) {
    if (insights != null && insights.predictions.isNotEmpty) {
      final p = insights.predictions.first;
      if (p.summary.trim().isNotEmpty) {
        return _clip(p.summary, 140);
      }
    }

    if (discoverFeed != null && discoverFeed.newItems.isNotEmpty) {
      final theme = discoverFeed.newItems.first.title.toLowerCase();
      return 'Whether you mention ${_titleCase(theme)} again in your next moment.';
    }

    if (discoverFeed != null && discoverFeed.strengthened.isNotEmpty) {
      final theme = discoverFeed.strengthened.first.title.toLowerCase();
      return 'If $theme comes up again when you speak — especially with the same tone.';
    }

    if (insights != null && insights.contradictions.isNotEmpty) {
      return 'Whether the same tension shows up, or one side feels truer.';
    }

    final emerging = beliefs?.emerging.firstOrNull;
    if (emerging != null) {
      return 'Whether ${_clip(emerging.statement, 72)} appears again.';
    }

    if (latest != null) {
      final themes = latest.reflection.recurringThemes
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (themes.isNotEmpty) {
        return 'If ${_titleCase(themes.first)} comes up in what you say next.';
      }
      return ConsumerUiCopy.tomorrowNoticePrompt;
    }

    return ConsumerUiCopy.tomorrowNoticePrompt;
  }

  List<String> _watchForChips({
    required JournalEntry? latest,
    required DiscoverLocalFeed? discoverFeed,
    required ArchiveBeliefsSnapshot? beliefs,
    required ArchiveInsightsSnapshot? insights,
    required String watchForNextTime,
  }) {
    final chips = <String>[];

    void add(String value) {
      final v = value.trim();
      if (v.isEmpty || chips.contains(v)) return;
      if (v.length > 42) return;
      chips.add(v);
    }

    if (discoverFeed != null) {
      for (final item in discoverFeed.newItems) {
        add(_chipFromTheme(item.title));
        if (chips.length >= 3) return chips;
      }
      for (final item in discoverFeed.strengthened) {
        add(_chipFromTheme(item.title));
        if (chips.length >= 3) return chips;
      }
    }

    if (latest != null) {
      final blob =
          '${latest.reflection.concreteObservation} ${latest.reflection.repeatedSignal} '
                  '${latest.transcript}'
              .toLowerCase();
      if (blob.contains('alone') ||
          blob.contains('myself') ||
          blob.contains('handle it')) {
        add('doing it alone');
      }
      if (blob.contains('yes') ||
          blob.contains('agree') ||
          blob.contains('too fast')) {
        add('saying yes too fast');
      }
      if (blob.contains('respons') || blob.contains('carry')) {
        add('feeling responsible');
      }
      if (blob.contains('help') && blob.contains('avoid')) {
        add('not asking for help');
      }
      for (final theme in latest.reflection.recurringThemes) {
        add(_chipFromTheme(theme));
        if (chips.length >= 3) return chips;
      }
    }

    final emerging = beliefs?.emerging.firstOrNull;
    if (emerging != null) {
      add(_clip(emerging.statement, 36));
    }

    if (chips.length < 2 && watchForNextTime.trim().isNotEmpty) {
      add(_clip(watchForNextTime, 36));
    }

    return chips.take(3).toList();
  }

  String _chipFromTheme(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return '';
    if (t.contains('work')) return 'work pressure';
    if (t.contains('family')) return 'family pressure';
    if (t.contains('rest') || t.contains('slow')) {
      return 'guilt when you slow down';
    }
    if (t.contains('respons')) return 'feeling responsible';
    if (t.length <= 28) return _titleCase(t);
    return _clip(_titleCase(t), 28);
  }

  List<JournalEntry> _entriesOnDay(List<JournalEntry> entries, DateTime day) {
    return entries.where((e) => _sameCalendarDay(e.createdAt, day)).toList();
  }

  bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _entryHighlight(JournalEntry entry) {
    final obs = ConsumerCopyGuard.userFacingObservation(
      entry.reflection.concreteObservation,
    );
    if (obs != null && obs.length >= 12) return _clip(obs, 100);
    final signal = ConsumerCopyGuard.userFacingObservation(
      entry.reflection.repeatedSignal,
    );
    if (signal != null && signal.length >= 12) return _clip(signal, 100);
    final transcript = entry.transcript.trim();
    if (transcript.length >= 20 &&
        !ConsumerCopyGuard.isSystemObservation(transcript)) {
      return _clip(transcript, 100);
    }
    return null;
  }

  String _titleCase(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  String _clip(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}

extension _FirstOrNullLoop<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
