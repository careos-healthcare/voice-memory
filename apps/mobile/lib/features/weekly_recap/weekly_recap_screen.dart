import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/onboarding/cloud_consent.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_builder.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Full week in the person's own words.
class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({
    required this.entries,
    this.now,
    this.weekEnding,
    this.cloudEnabled,
    this.cloudSummary,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;
  final DateTime? weekEnding;
  final bool? cloudEnabled;
  final WeeklyRecap? cloudSummary;

  static const title = 'Your week in your own words';

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final _headerKey = GlobalKey();
  AudioPlayer? _player;
  late final BuiltWeeklyRecap _recap = _cached();
  bool _cloudOn = false;
  List<String> _aiSentences = const [];

  @override
  void initState() {
    super.initState();
    final provided = widget.cloudEnabled;
    if (provided != null) {
      _cloudOn = provided;
      _aiSentences = _sentences(widget.cloudSummary);
      return;
    }
    unawaited(_loadCloud());
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  BuiltWeeklyRecap _cached() {
    final now = widget.now ?? DateTime.now();
    final ending = widget.weekEnding ?? WeeklyRecapBuilder.recapSunday(now);
    return WeeklyRecapCache.read(ending) ??
        WeeklyRecapCache.put(
          WeeklyRecapBuilder.build(
            widget.entries,
            now: now,
            weekEnding: ending,
          ),
        );
  }

  List<String> _sentences(WeeklyRecap? summary) {
    if (!_cloudOn || summary == null) return const [];
    return WeeklyRecapBuilder.citedSentences(
      summary: summary.summary,
      citations: [
        for (final citation in summary.verbatimCitations)
          (text: citation.text, entryId: citation.entryId),
      ],
      validEntryIds: {for (final entry in _recap.entries) entry.id},
    );
  }

  Future<void> _loadCloud() async {
    final enabled = await CloudConsent().isEnabled();
    if (!mounted) return;
    setState(() => _cloudOn = enabled);
    if (!enabled || !AppServices.isInitialized || _recap.entries.isEmpty) {
      return;
    }
    try {
      final result = await AppServices.instance.httpTransport.post(
        '/api/weekly-reflection',
        body: {
          'entries': [
            for (final entry in _recap.entries)
              {
                'entryId': entry.id,
                'text': entry.transcript,
                'timestamp': entry.createdAt.toUtc().toIso8601String(),
              },
          ],
        },
      );
      final summary = result.when(
        success: (response) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map) return null;
          return WeeklyRecap.fromJson(Map<String, Object?>.from(decoded));
        },
        onFailure: (_) => null,
      );
      if (!mounted || summary == null) return;
      setState(() => _aiSentences = _sentences(summary));
    } on Object {
      return;
    }
  }

  String get _rangeLabel {
    String day(DateTime value) => '${value.day} ${_month(value.month)}';
    return '${day(_recap.rangeStart)} – ${day(_recap.rangeEnd)} ${_recap.rangeEnd.year}';
  }

  String _month(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  Future<void> _shareImage() async {
    final boundary =
        _headerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/weekly-recap.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: WeeklyRecapScreen.title);
  }

  Future<void> _savePdf() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/weekly-recap.pdf');
    await BookExporter.save(
      JournalBook(
        title: WeeklyRecapScreen.title,
        subtitle: _rangeLabel,
        entries: [
          for (final entry in _recap.entries)
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
    ], subject: WeeklyRecapScreen.title);
  }

  Future<void> _playPlaylist() async {
    final clips = _recap.listenBack;
    if (clips.isEmpty) return;
    final player = _player ??= AudioPlayer();
    for (final clip in clips) {
      await player.stop();
      await player.play(DeviceFileSource(clip.audioPath));
      if (clip.startSeconds > 0) {
        await player.seek(Duration(seconds: clip.startSeconds));
      }
      await player.onPlayerComplete.first.timeout(
        Duration(seconds: clip.clipSeconds),
        onTimeout: () {},
      );
      await player.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(WeeklyRecapScreen.title)),
      body: ListView(
        key: const Key('weekly_recap_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          RepaintBoundary(
            key: _headerKey,
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    WeeklyRecapScreen.title,
                    key: const Key('weekly_recap_title'),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(_rangeLabel, key: const Key('weekly_recap_range')),
                  const SizedBox(height: 12),
                  Text(
                    '${_recap.daysRecorded} of 7 days',
                    key: const Key('weekly_recap_days'),
                  ),
                  Text(
                    '${_recap.totalMinutes} ${_recap.totalMinutes == 1 ? 'minute' : 'minutes'}',
                    key: const Key('weekly_recap_minutes'),
                  ),
                ],
              ),
            ),
          ),
          if (_recap.entries.isNotEmpty)
            ViewEvidenceInlineLink(
              entryIds: [for (final entry in _recap.entries) entry.id],
              surface: 'weekly_recap',
              claimContext:
                  '${_recap.daysRecorded} of 7 days, ${_recap.totalMinutes} minutes',
            ),
          if (_recap.themes.isNotEmpty) ...[
            const _Heading('Repeated themes'),
            for (final quote in _recap.themes) _QuoteBlock(quote: quote),
          ],
          if (_recap.thenAndNow case final pair?) ...[
            const _Heading('Then and now'),
            Text('This week', style: theme.textTheme.labelLarge),
            _QuoteBlock(quote: pair.now),
            Text('Earlier', style: theme.textTheme.labelLarge),
            _QuoteBlock(quote: pair.then),
          ],
          if (_recap.moods.isNotEmpty) ...[
            const _Heading('Moods'),
            Text(_recap.moods.join(', '), key: const Key('weekly_recap_moods')),
          ],
          if (_recap.places.isNotEmpty) ...[
            const _Heading('Places'),
            Text(
              _recap.places.join(', '),
              key: const Key('weekly_recap_places'),
            ),
          ],
          if (_recap.listenBack.isNotEmpty) ...[
            const _Heading('Listen back'),
            TextButton.icon(
              key: const Key('weekly_recap_playlist'),
              onPressed: () => unawaited(_playPlaylist()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
          ],
          if (_cloudOn && _aiSentences.isNotEmpty) ...[
            const _Heading('Written by AI from your entries'),
            for (final sentence in _aiSentences)
              Text(sentence, key: const Key('weekly_ai_sentence')),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('weekly_recap_share_image'),
            onPressed: () => unawaited(_shareImage()),
            child: const Text('Share as image'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('weekly_recap_save_pdf'),
            onPressed: () => unawaited(_savePdf()),
            child: const Text('Save as PDF'),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quote});

  final WeeklyQuote quote;

  @override
  Widget build(BuildContext context) {
    final day = '${quote.date.day} ${_month(quote.date.month)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(day),
        Text('“${quote.sentence}”', key: Key('weekly_quote_${quote.entryId}')),
        ViewEvidenceInlineLink(
          entryIds: [quote.entryId],
          surface: 'weekly_recap',
          claimContext: quote.sentence,
        ),
        if (quote.audioPath != null)
          _PlayButton(
            entryId: quote.entryId,
            audioPath: quote.audioPath!,
            startSeconds: quote.startSeconds ?? 0,
          ),
      ],
    );
  }

  String _month(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.entryId,
    required this.audioPath,
    required this.startSeconds,
  });

  final String entryId;
  final String audioPath;
  final int startSeconds;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  AudioPlayer? _player;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('weekly_play_${widget.entryId}'),
      onPressed: () async {
        final player = _player ??= AudioPlayer();
        await player.stop();
        await player.play(DeviceFileSource(widget.audioPath));
        if (widget.startSeconds > 0) {
          await player.seek(Duration(seconds: widget.startSeconds));
        }
      },
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Play'),
    );
  }
}
