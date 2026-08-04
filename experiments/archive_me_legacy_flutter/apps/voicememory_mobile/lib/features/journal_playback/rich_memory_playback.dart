import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../monetization/domain/services/monetization_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';
import '../explainable_conclusion/explainable_conclusion_widgets.dart';
import '../../services/app_services.dart';
import '../../services/privacy/audio_vault_service.dart';

abstract interface class MemoryAudioPlayer {
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged;
  Stream<void> get onPlayerComplete;

  Future<void> play(Source source);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setReleaseMode(ReleaseMode releaseMode);
  Future<void> dispose();
}

final class AudioplayersMemoryAudioPlayer implements MemoryAudioPlayer {
  AudioplayersMemoryAudioPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> play(Source source) => _player.play(source);
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) =>
      _player.setReleaseMode(releaseMode);
  @override
  Future<void> dispose() => _player.dispose();
}

class MemoryPlaybackController extends ChangeNotifier {
  MemoryPlaybackController({
    MemoryAudioPlayer? player,
    AudioVaultService? audioVault,
  }) : _player = player ?? AudioplayersMemoryAudioPlayer(),
       // Public named parameter cannot expose a private field name.
       // ignore: prefer_initializing_formals
       _audioVault = audioVault {
    _subscriptions.add(
      _player.onPositionChanged.listen((value) {
        position = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onDurationChanged.listen((value) {
        duration = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onPlayerStateChanged.listen((value) {
        isPlaying = value == PlayerState.playing;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.onPlayerComplete.listen((_) {
        position = duration;
        isPlaying = false;
        completionCount += 1;
        _sourceLoaded = false;
        unawaited(_releaseLease());
        notifyListeners();
      }),
    );
  }

  final MemoryAudioPlayer _player;
  final AudioVaultService? _audioVault;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  JournalEntry? entry;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  int completionCount = 0;
  bool _sourceLoaded = false;
  AudioVaultLease? _lease;
  String? errorMessage;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  void load(JournalEntry value) {
    if (entry?.id != value.id) {
      unawaited(_player.stop());
      unawaited(_releaseLease());
    }
    entry = value;
    position = Duration.zero;
    duration = Duration(seconds: value.durationSeconds);
    isPlaying = false;
    _sourceLoaded = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> toggle() async {
    final value = entry;
    final reference = value?.localAudioReference ?? '';
    if (value == null || reference.isEmpty) {
      errorMessage = 'Audio is not available on this device.';
      notifyListeners();
      return false;
    }
    try {
      final vault =
          _audioVault ??
          (AppServices.isInitialized
              ? AppServices.instance.journalAudioVault
              : null);
      final isVaultAudio =
          reference.startsWith(AudioVaultService.referencePrefix) ||
          reference.endsWith('.enc');
      final exists = isVaultAudio
          ? await vault?.exists(reference) ?? false
          : File(reference).existsSync();
      if (!exists) {
        errorMessage = 'Audio is not available on this device.';
        notifyListeners();
        return false;
      }
      if (isPlaying) {
        await _player.pause();
        return false;
      } else if (!_sourceLoaded) {
        await _player.setReleaseMode(ReleaseMode.stop);
        var playablePath = reference;
        if (isVaultAudio) {
          if (vault == null) {
            throw const AudioVaultException('Audio vault is unavailable.');
          }
          await _releaseLease();
          _lease = await vault.openDecryptedLease(reference);
          playablePath = _lease!.file.path;
        }
        await _player.play(DeviceFileSource(playablePath));
        _sourceLoaded = true;
      } else {
        await _player.resume();
      }
      errorMessage = null;
      return true;
    } on Object {
      await _releaseLease();
      _sourceLoaded = false;
      errorMessage = 'This recording could not be played.';
      notifyListeners();
      return false;
    }
  }

  Future<void> seek(Duration target) async {
    final upperBound = duration.inMilliseconds;
    final milliseconds = target.inMilliseconds.clamp(0, upperBound);
    position = Duration(milliseconds: milliseconds);
    notifyListeners();
    if (_sourceLoaded) {
      await _player.seek(position);
    }
  }

  Future<void> skipBy(Duration delta) => seek(position + delta);

  Future<bool> playFrom(Duration timestamp) async {
    final started = isPlaying || await toggle();
    if (!started) return false;
    await seek(timestamp);
    return true;
  }

  Future<void> stop() async {
    await _player.stop();
    _sourceLoaded = false;
    await _releaseLease();
  }

  Future<void> _releaseLease() async {
    final lease = _lease;
    _lease = null;
    await lease?.close();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_releaseLease());
    unawaited(_player.dispose());
    super.dispose();
  }
}

class RichMemoryPlayback extends StatefulWidget {
  const RichMemoryPlayback({
    super.key,
    required this.entry,
    required this.hasProAccess,
    this.controller,
    this.analytics = const ProductMonetizationAnalyticsEngine(),
  });

  final JournalEntry entry;
  final bool hasProAccess;
  final MemoryPlaybackController? controller;
  final AnalyticsEngine analytics;

  @override
  State<RichMemoryPlayback> createState() => _RichMemoryPlaybackState();
}

class _RichMemoryPlaybackState extends State<RichMemoryPlayback> {
  late MemoryPlaybackController _controller;
  late bool _ownsController;
  int _lastCompletionCount = 0;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant RichMemoryPlayback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.removeListener(_refresh);
      if (_ownsController) _controller.dispose();
      _attachController();
    } else if (oldWidget.entry.id != widget.entry.id) {
      _controller.load(widget.entry);
    }
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MemoryPlaybackController();
    _controller.load(widget.entry);
    _lastCompletionCount = _controller.completionCount;
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (_controller.completionCount > _lastCompletionCount) {
      _lastCompletionCount = _controller.completionCount;
      widget.analytics.logEvent(
        'playback_completed',
        parameters: _playbackParameters(),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final started = await _controller.toggle();
    if (!started) return;
    widget.analytics.logEvent(
      'playback_started',
      parameters: _playbackParameters(),
    );
  }

  void _trackScrub(double value) {
    widget.analytics.logEvent(
      'playback_scrubbed',
      parameters: {
        ..._playbackParameters(),
        'position_seconds': (_controller.duration.inSeconds * value).round(),
      },
    );
  }

  Map<String, Object> _playbackParameters() => {
    'duration_seconds': widget.entry.durationSeconds,
  };

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalAudio = widget.entry.localAudioReference?.isNotEmpty == true;
    final conclusion = widget.entry.reflection.explainableConclusion;
    final gated = conclusion == null
        ? null
        : ExplainableConclusionRenderGate.visible(
            conclusion,
            canonicalTranscripts: {widget.entry.id: widget.entry.transcript},
          );
    return Container(
      key: const Key('rich_memory_playback'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memory playback',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SynchronizedTranscript(
            transcript: widget.entry.transcript,
            progress: _controller.progress,
          ),
          if (gated != null) ...[
            const SizedBox(height: AppSpacing.md),
            ExplainableConclusionCard(
              conclusion: gated,
              onShowHistory: () async {
                if (!AppServices.isInitialized) return;
                final history = await AppServices
                    .instance
                    .explainabilityHistoryStore
                    .byConclusionId(gated.value.id);
                if (!context.mounted) return;
                await ExplainableHistorySheet.show(
                  context,
                  entries: history,
                  canonicalTranscripts: {
                    widget.entry.id: widget.entry.transcript,
                  },
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label:
                'Playback position ${_formatDuration(_controller.position)} '
                'of ${_formatDuration(_controller.duration)}',
            slider: true,
            child: Slider(
              key: const Key('memory_playback_progress'),
              value: _controller.progress,
              onChanged: hasLocalAudio
                  ? (value) => unawaited(
                      _controller.seek(
                        Duration(
                          milliseconds:
                              (_controller.duration.inMilliseconds * value)
                                  .round(),
                        ),
                      ),
                    )
                  : null,
              onChangeEnd: hasLocalAudio ? _trackScrub : null,
            ),
          ),
          Row(
            children: [
              Expanded(child: Text(_formatDuration(_controller.position))),
              Expanded(
                child: Text(
                  _formatDuration(_controller.duration),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Semantics(
                  button: true,
                  label: 'Rewind playback 10 seconds',
                  child: ExcludeSemantics(
                    child: IconButton(
                      key: const Key('memory_playback_rewind'),
                      tooltip: 'Back 10 seconds',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: hasLocalAudio
                          ? () => unawaited(
                              _controller.skipBy(const Duration(seconds: -10)),
                            )
                          : null,
                      icon: const Icon(Icons.replay_10),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: _controller.isPlaying
                      ? 'Pause memory playback'
                      : 'Play memory recording',
                  child: ExcludeSemantics(
                    child: FilledButton.tonalIcon(
                      key: const Key('memory_playback_toggle'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: hasLocalAudio
                          ? () => unawaited(_togglePlayback())
                          : null,
                      icon: Icon(
                        _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(_controller.isPlaying ? 'Pause' : 'Play'),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Forward playback 10 seconds',
                  child: ExcludeSemantics(
                    child: IconButton(
                      key: const Key('memory_playback_forward'),
                      tooltip: 'Forward 10 seconds',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: hasLocalAudio
                          ? () => unawaited(
                              _controller.skipBy(const Duration(seconds: 10)),
                            )
                          : null,
                      icon: const Icon(Icons.forward_10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!hasLocalAudio) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text('Audio is not available on this device.'),
          ] else if (_controller.errorMessage case final error?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SynchronizedTranscript extends StatelessWidget {
  const _SynchronizedTranscript({
    required this.transcript,
    required this.progress,
  });

  final String transcript;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final words = transcript.trim().split(RegExp(r'\s+'));
    final highlightedCount = (words.length * progress).floor();
    final completed = words.take(highlightedCount).join(' ');
    final remaining = words.skip(highlightedCount).join(' ');

    return Semantics(
      label: 'Synchronized transcript: $transcript',
      child: Text.rich(
        TextSpan(
          children: [
            if (completed.isNotEmpty)
              TextSpan(
                text: '$completed${remaining.isEmpty ? '' : ' '}',
                style: const TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            TextSpan(text: remaining),
          ],
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
      ),
    );
  }
}
