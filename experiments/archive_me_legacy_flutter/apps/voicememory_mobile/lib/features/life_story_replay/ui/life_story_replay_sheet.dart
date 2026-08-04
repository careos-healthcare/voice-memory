import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../life_story_models.dart';
import '../replay_sync_service.dart';

typedef LifeStoryPackageExporter = Future<void> Function();

class LifeStoryReplaySheet extends StatefulWidget {
  const LifeStoryReplaySheet({
    super.key,
    required this.service,
    this.generate,
    this.onCameraTarget,
    this.onExport,
    this.onOpenCodex,
    this.onClose,
  });

  final ReplaySyncService service;
  final Future<void> Function()? generate;
  final ValueChanged<ReplayCameraTarget>? onCameraTarget;
  final LifeStoryPackageExporter? onExport;
  final VoidCallback? onOpenCodex;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required ReplaySyncService service,
    Future<void> Function()? generate,
    ValueChanged<ReplayCameraTarget>? onCameraTarget,
    LifeStoryPackageExporter? onExport,
    VoidCallback? onOpenCodex,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => LifeStoryReplaySheet(
      service: service,
      generate: generate,
      onCameraTarget: onCameraTarget,
      onExport: onExport,
      onOpenCodex: onOpenCodex,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );

  @override
  State<LifeStoryReplaySheet> createState() => _LifeStoryReplaySheetState();
}

class _LifeStoryReplaySheetState extends State<LifeStoryReplaySheet> {
  StreamSubscription<ReplayCameraTarget>? _cameraSubscription;
  bool _generating = false;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _cameraSubscription = widget.service.cameraTargets.listen(
      (target) => widget.onCameraTarget?.call(target),
    );
    if (widget.service.script == null && widget.generate != null) {
      unawaited(_generate());
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      await widget.generate?.call();
    } on Object {
      _generationError = 'The cinematic replay could not be prepared.';
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    unawaited(_cameraSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final script = widget.service.script;
    return Material(
      color: const Color(0xff05060b).withValues(alpha: .94),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _CinematicBackdrop()),
            Column(
              children: [
                _Header(
                  title: script?.title ?? 'Cinematic Life Story',
                  onClose: widget.onClose,
                ),
                Expanded(
                  child: script == null
                      ? _EmptyState(
                          generating: _generating,
                          error: _generationError,
                          onGenerate: widget.generate == null
                              ? null
                              : _generate,
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          child: Column(
                            children: [
                              _HeroChapter(
                                chapter: _activeChapter(script),
                                position: widget.service.position,
                              ),
                              const SizedBox(height: 22),
                              GlassmorphicContainer(
                                key: const Key('life-story-transport'),
                                fillColor: theme.colorScheme.surface,
                                opacity: .64,
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  20,
                                  18,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 76,
                                      child: CustomPaint(
                                        key: const Key('life-story-waveform'),
                                        painter: _WaveformPainter(
                                          progress: widget.service.progress,
                                          color: theme.colorScheme.primary,
                                          chapterFractions: _chapterFractions(
                                            script,
                                          ),
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                    Slider(
                                      key: const Key('life-story-scrubber'),
                                      value: widget.service.progress,
                                      onChanged: (value) => widget.service.seek(
                                        Duration(
                                          milliseconds:
                                              (widget
                                                          .service
                                                          .duration
                                                          .inMilliseconds *
                                                      value)
                                                  .round(),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_time(widget.service.position)),
                                        IconButton.filled(
                                          key: const Key(
                                            'life-story-play-pause',
                                          ),
                                          tooltip: widget.service.isPlaying
                                              ? 'Pause'
                                              : 'Play',
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            widget.service.togglePlayback();
                                          },
                                          icon: Icon(
                                            widget.service.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                        ),
                                        Text(_time(widget.service.duration)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final rate in const [
                                          1.0,
                                          1.5,
                                          2.0,
                                        ])
                                          ChoiceChip(
                                            key: Key(
                                              'life-story-speed-${rate}x',
                                            ),
                                            label: Text('${rate.g}x'),
                                            selected:
                                                widget.service.playbackRate ==
                                                rate,
                                            onSelected: (_) => widget.service
                                                .setPlaybackRate(rate),
                                          ),
                                        FilterChip(
                                          key: const Key('life-story-ambient'),
                                          avatar: const Icon(
                                            Icons.graphic_eq,
                                            size: 18,
                                          ),
                                          label: const Text('Ambient'),
                                          selected:
                                              widget.service.ambientEnabled,
                                          onSelected:
                                              widget.service.setAmbientEnabled,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _ChapterRail(
                                script: script,
                                position: widget.service.position,
                                onSeek: widget.service.seek,
                              ),
                              if (widget.service.errorMessage case final error?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                key: const Key('life-story-export'),
                                onPressed: widget.onExport == null
                                    ? null
                                    : () async {
                                        HapticFeedback.selectionClick();
                                        await widget.onExport!.call();
                                      },
                                icon: const Icon(Icons.lock_outline),
                                label: const Text(
                                  'Export Encrypted Cinematic Package',
                                ),
                              ),
                              if (widget.onOpenCodex != null)
                                OutlinedButton.icon(
                                  key: const Key('life-story-open-codex'),
                                  onPressed: widget.onOpenCodex,
                                  icon: const Icon(Icons.auto_stories_outlined),
                                  label: const Text(
                                    'Publish as Sovereign Codex',
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LifeStoryScriptChapter _activeChapter(LifeStoryReplayScript script) {
    var active = script.chapters.first;
    for (final chapter in script.chapters) {
      if (widget.service.position >= chapter.start) active = chapter;
    }
    return active;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.onClose});
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
    child: Row(
      children: [
        const Icon(Icons.movie_filter_outlined),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          key: const Key('life-story-close'),
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _HeroChapter extends StatelessWidget {
  const _HeroChapter({required this.chapter, required this.position});
  final LifeStoryScriptChapter chapter;
  final Duration position;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Now playing ${chapter.title}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Text(
            'CHAPTER ${(chapter.start.inSeconds ~/ 60 + 1).toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chapter.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            chapter.narration,
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

class _ChapterRail extends StatelessWidget {
  const _ChapterRail({
    required this.script,
    required this.position,
    required this.onSeek,
  });
  final LifeStoryReplayScript script;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chapter in script.chapters)
          ActionChip(
            key: Key('life-story-chapter-${chapter.id}'),
            avatar: Icon(
              position >= chapter.start &&
                      position < chapter.start + chapter.duration
                  ? Icons.radio_button_checked
                  : Icons.circle_outlined,
              size: 16,
            ),
            label: Text(chapter.title),
            onPressed: () => onSeek(chapter.start),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.generating,
    required this.error,
    this.onGenerate,
  });
  final bool generating;
  final String? error;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (generating) const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(
            error ??
                (generating
                    ? 'Weaving your encrypted graph into chapters…'
                    : 'Your cinematic retrospective is ready to be generated.'),
            textAlign: TextAlign.center,
          ),
          if (!generating && onGenerate != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('life-story-generate'),
              onPressed: onGenerate,
              child: const Text('Generate Replay'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(-.35, -.5),
        radius: 1.3,
        colors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: .2),
          Colors.transparent,
        ],
      ),
    ),
  );
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.progress,
    required this.color,
    required this.chapterFractions,
  });
  final double progress;
  final Color color;
  final List<double> chapterFractions;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = max(20, size.width ~/ 5);
    final paint = Paint()..strokeWidth = 2.2;
    for (var index = 0; index < bars; index++) {
      final fraction = index / max(1, bars - 1);
      final wave =
          .2 + .8 * (sin(index * .71).abs() * .6 + sin(index * .19).abs() * .4);
      final height = size.height * wave;
      paint.color = color.withValues(alpha: fraction <= progress ? .95 : .25);
      final x = fraction * size.width;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
    paint
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .55);
    for (final fraction in chapterFractions.skip(1)) {
      final x = fraction * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.chapterFractions != chapterFractions;
}

List<double> _chapterFractions(LifeStoryReplayScript script) => [
  for (final chapter in script.chapters)
    script.duration.inMilliseconds == 0
        ? 0
        : chapter.start.inMilliseconds / script.duration.inMilliseconds,
];

String _time(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

extension on double {
  String get g =>
      this == roundToDouble() ? toInt().toString() : toStringAsFixed(1);
}
