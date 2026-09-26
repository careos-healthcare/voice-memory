import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/insights/services/local_recap_generator.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_builder.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_screen.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Full week in the person's own words, built on the device.
class WeeklyRecapView extends StatefulWidget {
  const WeeklyRecapView({
    required this.entries,
    this.weekEnding,
    this.now,
    this.recap,
    this.cloudSummary,
    this.loadCloudSummary,
    this.onShare,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? weekEnding;
  final DateTime? now;
  final LocalWeeklyRecap? recap;
  final WeeklyRecap? cloudSummary;
  final Future<WeeklyRecap?> Function()? loadCloudSummary;
  final Future<void> Function(LocalWeeklyRecap recap)? onShare;

  static const title = 'Your week in your own words';

  @override
  State<WeeklyRecapView> createState() => _WeeklyRecapViewState();
}

class _WeeklyRecapViewState extends State<WeeklyRecapView> {
  LocalWeeklyRecap? _recap;
  WeeklyRecap? _cloud;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final provided = widget.recap;
    if (provided != null) {
      _recap = provided;
      _cloud = widget.cloudSummary;
      _loading = false;
      if (widget.cloudSummary == null && widget.loadCloudSummary != null) {
        unawaited(_loadCloud());
      }
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final generator = const LocalRecapGenerator();
    final built = generator.build(
      widget.entries,
      now: widget.now,
      weekEnding: widget.weekEnding,
    );
    final compared = await generator.withEarlierMatch(built);
    if (!mounted) return;
    setState(() {
      _recap = compared;
      _loading = false;
    });
    await _loadCloud();
  }

  Future<void> _loadCloud() async {
    final loader = widget.loadCloudSummary ?? _fetchCloudSummary;
    final summary = await loader();
    if (!mounted || summary == null) return;
    setState(() => _cloud = summary);
  }

  Future<WeeklyRecap?> _fetchCloudSummary() async {
    if (!AppServices.isInitialized) return null;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    if (!preferences.isCloudSyncEnabled) return null;
    final week = _recap?.entries ?? const <JournalEntry>[];
    if (week.isEmpty) return null;
    try {
      final result = await AppServices.instance.httpTransport.post(
        '/api/weekly-reflection',
        body: {
          'entries': [
            for (final entry in week)
              {
                'entryId': entry.id,
                'text': entry.transcript,
                'timestamp': entry.createdAt.toUtc().toIso8601String(),
              },
          ],
        },
      );
      return result.when(
        success: (response) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map) return null;
          return WeeklyRecap.fromJson(Map<String, Object?>.from(decoded));
        },
        onFailure: (_) => null,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _share(LocalWeeklyRecap recap) async {
    final custom = widget.onShare;
    if (custom != null) {
      await custom(recap);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/weekly-recap.pdf');
    await BookExporter.save(
      JournalBook(
        title: WeeklyRecapView.title,
        subtitle: weekEndingLabel(recap.weekEnding),
        entries: [
          for (final entry in recap.entries)
            JournalBookEntry(
              dateString: entry.createdAt.toLocal().toIso8601String().substring(
                0,
                10,
              ),
              transcript: entry.transcript,
              mood: entry.reflection.mood,
              location: entry.display.locationLabel,
            ),
        ],
      ),
      path: file.path,
    );
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: WeeklyRecapView.title);
  }

  @override
  Widget build(BuildContext context) {
    final recap = _recap;
    return Scaffold(
      appBar: AppBar(
        title: const Text(WeeklyRecapView.title),
        actions: [
          if (recap != null)
            IconButton(
              key: const Key('weekly_recap_share'),
              onPressed: () => unawaited(_share(recap)),
              icon: const Icon(Icons.share),
            ),
        ],
      ),
      body: _loading || recap == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('weekly_recap_view'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  weekEndingLabel(recap.weekEnding),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${recap.daysRecorded} ${recap.daysRecorded == 1 ? 'day' : 'days'} recorded',
                  key: const Key('weekly_recap_days'),
                ),
                Text(
                  '${recap.totalMinutes} ${recap.totalMinutes == 1 ? 'minute' : 'minutes'}',
                  key: const Key('weekly_recap_minutes'),
                ),
                if (recap.entries.isNotEmpty)
                  ViewEvidenceInlineLink(
                    entryIds: [for (final entry in recap.entries) entry.id],
                    surface: 'weekly_recap',
                    claimContext:
                        '${recap.daysRecorded} days, ${recap.totalMinutes} minutes',
                  ),
                if (recap.themes.isNotEmpty) ...[
                  const _SectionTitle('Themes'),
                  for (final theme in recap.themes) _ThemeRow(theme: theme),
                ],
                if (recap.moods.isNotEmpty) ...[
                  const _SectionTitle('Moods'),
                  Text(
                    recap.moods.join(', '),
                    key: const Key('weekly_recap_moods'),
                  ),
                ],
                if (recap.places.isNotEmpty) ...[
                  const _SectionTitle('Places'),
                  Text(
                    recap.places.join(', '),
                    key: const Key('weekly_recap_places'),
                  ),
                ],
                if (recap.thenVsNow != null)
                  _ThenVsNowSection(pair: recap.thenVsNow!),
                if (recap.listenBack.isNotEmpty) ...[
                  const _SectionTitle('Listen back'),
                  for (final clip in recap.listenBack)
                    _ClipRow(
                      entryId: clip.entryId,
                      quote: clip.quote,
                      audioPath: clip.audioPath,
                    ),
                ],
                if (_cloud != null) _CloudSummary(summary: _cloud!),
              ],
            ),
    );
  }
}

String weekEndingLabel(DateTime ending) {
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
  return 'Week ending ${ending.day} ${months[ending.month - 1]} ${ending.year}';
}

/// Earlier weeks, opened into the same recap.
class PastWeeklyRecaps extends StatelessWidget {
  const PastWeeklyRecaps({
    required this.entries,
    this.now,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final endings = WeeklyRecapBuilder.pastWeekEndings(entries, now: clock);
    for (final ending in endings) {
      WeeklyRecapCache.read(ending) ??
          WeeklyRecapCache.put(
            WeeklyRecapBuilder.build(
              entries,
              now: clock,
              weekEnding: ending,
            ),
          );
    }
    if (endings.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('past_weekly_recaps'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Past recaps',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: endings.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final ending = endings[index];
              final label = weekEndingLabel(ending);
              return ActionChip(
                key: Key(
                  'past_week_${ending.toIso8601String().substring(0, 10)}',
                ),
                label: Text(label),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WeeklyRecapScreen(
                        entries: entries,
                        weekEnding: ending,
                        now: now,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.theme});

  final RecapThemeCitation theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(theme.label, key: Key('weekly_theme_${theme.label}')),
        Text(
          '“${theme.quote}”',
          key: Key('weekly_theme_quote_${theme.entryId}'),
        ),
        ViewEvidenceInlineLink(
          entryIds: [theme.entryId],
          surface: 'weekly_recap',
          claimContext: theme.label,
        ),
        if (theme.audioPath != null)
          _ClipPlayButton(entryId: theme.entryId, audioPath: theme.audioPath!),
      ],
    );
  }
}

class _ThenVsNowSection extends StatelessWidget {
  const _ThenVsNowSection({required this.pair});

  final ThenVsNow pair;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Then vs now'),
        Text(
          'Then: “${pair.earlierQuote}”',
          key: const Key('weekly_then_quote'),
        ),
        Text(
          'Now: “${pair.thisWeekQuote}”',
          key: const Key('weekly_now_quote'),
        ),
        ViewEvidenceInlineLink(
          entryIds: [pair.earlierEntryId, pair.thisWeekEntryId],
          surface: 'weekly_recap',
          claimContext: 'Then vs now',
        ),
      ],
    );
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({
    required this.entryId,
    required this.quote,
    required this.audioPath,
  });

  final String entryId;
  final String quote;
  final String audioPath;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('weekly_listen_$entryId'),
      contentPadding: EdgeInsets.zero,
      title: Text('“$quote”'),
      trailing: _ClipPlayButton(entryId: entryId, audioPath: audioPath),
    );
  }
}

class _CloudSummary extends StatelessWidget {
  const _CloudSummary({required this.summary});

  final WeeklyRecap summary;

  @override
  Widget build(BuildContext context) {
    final ids = [
      for (final citation in summary.verbatimCitations)
        if (citation.entryId.isNotEmpty) citation.entryId,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Written by AI from your entries'),
        for (final sentence in WeeklyRecapBuilder.citedSentences(
          summary: summary.summary,
          citations: [
            for (final citation in summary.verbatimCitations)
              (text: citation.text, entryId: citation.entryId),
          ],
          validEntryIds: {
            for (final citation in summary.verbatimCitations)
              if (citation.entryId.isNotEmpty) citation.entryId,
          },
        ))
          Text(sentence, key: const Key('weekly_ai_summary')),
        if (ids.isNotEmpty)
          ViewEvidenceInlineLink(
            entryIds: ids,
            surface: 'weekly_recap',
            claimContext: summary.summary,
          ),
        for (final citation in summary.verbatimCitations)
          Text(
            '“${citation.text}”',
            key: Key('weekly_ai_citation_${citation.entryId}'),
          ),
      ],
    );
  }
}

class _ClipPlayButton extends StatefulWidget {
  const _ClipPlayButton({required this.entryId, required this.audioPath});

  final String entryId;
  final String audioPath;

  @override
  State<_ClipPlayButton> createState() => _ClipPlayButtonState();
}

class _ClipPlayButtonState extends State<_ClipPlayButton> {
  AudioPlayer? _player;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _play() async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(DeviceFileSource(widget.audioPath));
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('weekly_play_${widget.entryId}'),
      onPressed: () => unawaited(_play()),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Play'),
    );
  }
}
