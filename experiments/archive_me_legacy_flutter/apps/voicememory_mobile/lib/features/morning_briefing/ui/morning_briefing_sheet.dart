import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../morning_briefing_audio.dart';
import '../morning_briefing_models.dart';

typedef MorningBriefingAudioLoader = Future<Uint8List?> Function();

class MorningBriefingCard extends StatelessWidget {
  const MorningBriefingCard({
    super.key,
    required this.briefing,
    required this.onPressed,
  });

  final MorningBriefing briefing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open today’s private morning briefing',
    child: ActionChip(
      key: const Key('morning-briefing-card'),
      avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
      label: const Text('Morning briefing'),
      onPressed: onPressed,
    ),
  );
}

class MorningBriefingSheet extends StatefulWidget {
  const MorningBriefingSheet({
    super.key,
    required this.briefing,
    required this.loadAudio,
    required this.onStartDayFocus,
    required this.onSnooze,
    required this.onJumpToGraph,
    required this.onClose,
    this.audioController,
  });

  final MorningBriefing briefing;
  final MorningBriefingAudioLoader loadAudio;
  final ValueChanged<String?> onStartDayFocus;
  final FutureOr<void> Function() onSnooze;
  final ValueChanged<String?> onJumpToGraph;
  final VoidCallback onClose;
  final MorningBriefingAudioController? audioController;

  @override
  State<MorningBriefingSheet> createState() => _MorningBriefingSheetState();
}

class _MorningBriefingSheetState extends State<MorningBriefingSheet>
    with SingleTickerProviderStateMixin {
  late final MorningBriefingAudioController _audio =
      widget.audioController ?? PlatformMorningBriefingAudioController();
  late final bool _ownsAudio = widget.audioController == null;
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _playing = false;
  bool _loading = false;
  String? _error;

  String? get _target =>
      widget.briefing.highlightedNodeId ?? widget.briefing.highlightedClusterId;

  @override
  void initState() {
    super.initState();
    unawaited(
      _audio.initialize(
        onStarted: () {
          if (!mounted) return;
          setState(() {
            _playing = true;
            _loading = false;
          });
          if (!MediaQuery.disableAnimationsOf(context)) {
            unawaited(_wave.repeat());
          }
          widget.onStartDayFocus(_target);
        },
        onCompleted: () {
          if (!mounted) return;
          _wave
            ..stop()
            ..value = 0;
          setState(() {
            _playing = false;
            _loading = false;
          });
        },
        onError: (message) {
          if (!mounted) return;
          _wave.stop();
          setState(() {
            _playing = false;
            _loading = false;
            _error = message;
          });
        },
      ),
    );
  }

  Future<void> _toggleAudio() async {
    if (_loading) return;
    if (_playing) {
      await _audio.stop();
      if (mounted) {
        setState(() => _playing = false);
        _wave
          ..stop()
          ..value = 0;
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _audio.play(
        narration: widget.briefing.narration,
        encryptedAudio: await widget.loadAudio(),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    if (_ownsAudio) unawaited(_audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      key: const Key('morning-briefing-sheet'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: .9),
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your morning briefing',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          key: const Key('morning-briefing-close'),
                          tooltip: 'Close morning briefing',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _BriefingWaveform(
                      animation: _wave,
                      playing: _playing,
                      loading: _loading,
                      onPressed: () => unawaited(_toggleAudio()),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricCard(
                          icon: Icons.favorite_outline,
                          label: 'Sleep quality',
                          value: widget.briefing.sleepQualityScore == 0
                              ? 'No Health data'
                              : '${widget.briefing.sleepQualityScore}/100',
                          badge: 'Apple Health',
                        ),
                        _MetricCard(
                          icon: Icons.spa_outlined,
                          label: 'Active small steps',
                          value: '${widget.briefing.activeHabitCount}',
                          badge: widget.briefing.bestHabitRun == 0
                              ? null
                              : '${widget.briefing.bestHabitRun}-day rhythm',
                        ),
                        _MetricCard(
                          icon: Icons.hub_outlined,
                          label: 'Graph focus',
                          value: _target == null ? 'Open canvas' : 'Ready',
                        ),
                        if (widget.briefing.museTriageCount > 0)
                          _MetricCard(
                            icon: Icons.auto_awesome_outlined,
                            label: 'Muse triage',
                            value:
                                '${widget.briefing.museTriageCount} cards ready',
                            badge: 'Private daily deck',
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  sliver: SliverList.builder(
                    itemCount: widget.briefing.sections.length,
                    itemBuilder: (context, index) {
                      final section = widget.briefing.sections[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(section.narrative),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_error != null)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Audio is unavailable. The visual briefing is still ready.',
                        key: const Key('morning-briefing-audio-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('morning-start-focus'),
                          onPressed: () => widget.onStartDayFocus(_target),
                          icon: const Icon(Icons.center_focus_strong),
                          label: const Text('Start Day Focus'),
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('morning-jump-graph'),
                          onPressed: () => widget.onJumpToGraph(_target),
                          icon: const Icon(Icons.hub_outlined),
                          label: const Text('Jump to Graph'),
                        ),
                        TextButton.icon(
                          key: const Key('morning-snooze'),
                          onPressed: () async {
                            await widget.onSnooze();
                            widget.onClose();
                          },
                          icon: const Icon(Icons.snooze),
                          label: const Text('Snooze Briefing'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BriefingWaveform extends StatelessWidget {
  const _BriefingWaveform({
    required this.animation,
    required this.playing,
    required this.loading,
    required this.onPressed,
  });

  final Animation<double> animation;
  final bool playing;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: playing ? 'Pause morning narration' : 'Play morning narration',
    child: ExcludeSemantics(
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const Key('morning-briefing-audio-toggle'),
          borderRadius: BorderRadius.circular(20),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 96,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  loading
                      ? Icons.hourglass_top
                      : playing
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => CustomPaint(
                      painter: _WavePainter(
                        phase: playing ? animation.value : 0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const bars = 22;
    final spacing = size.width / bars;
    for (var index = 0; index < bars; index++) {
      final wave = (math.sin((index / bars + phase) * math.pi * 4) + 1) / 2;
      final height = 12 + wave * (size.height * .55);
      final x = spacing * index + spacing / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            if (badge != null) Text(badge!, maxLines: 1),
          ],
        ),
      ),
    ),
  );
}
