import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../audio_graph_mapper.dart';
import '../whispering_vault_controller.dart';

final class WhisperingVaultSheet extends StatelessWidget {
  const WhisperingVaultSheet({
    required this.controller,
    this.onNodeSelected,
    this.onClose,
    super.key,
  });

  final WhisperingVaultViewModel controller;
  final ValueChanged<String>? onNodeSelected;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required WhisperingVaultViewModel controller,
    ValueChanged<String>? onNodeSelected,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'whispering-vault',
    builder: (panelContext) => WhisperingVaultSheet(
      controller: controller,
      onNodeSelected: onNodeSelected,
      onClose: () => Navigator.pop(panelContext),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                key: const Key('whisper-particle-glow'),
                painter: _ParticleGlowPainter(
                  waveform: controller.waveform,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'The Whispering Vault',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      const Chip(
                        avatar: Icon(Icons.cloud_off, size: 16),
                        label: Text('Offline'),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GlassmorphicContainer(
                      fillColor: theme.colorScheme.surface,
                      opacity: .56,
                      blurSigma: 18,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 112,
                            child: CustomPaint(
                              key: const Key('whisper-waveform'),
                              painter: _WhisperWaveformPainter(
                                values: controller.waveform,
                                color: theme.colorScheme.primary,
                                active:
                                    controller.state ==
                                    WhisperingVaultState.recording,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Text(
                            _status(controller.state),
                            key: const Key('whisper-state-label'),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _transcript(context)),
                          if (controller.errorMessage case final error?)
                            Text(
                              error,
                              key: const Key('whisper-error'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          const SizedBox(height: 12),
                          if (controller.state == WhisperingVaultState.ready)
                            _playbackControls(),
                          IconButton.filled(
                            key: const Key('whisper-record-toggle'),
                            tooltip:
                                controller.state ==
                                    WhisperingVaultState.recording
                                ? 'Stop recording'
                                : 'Start offline recording',
                            iconSize: 42,
                            onPressed:
                                controller.state ==
                                        WhisperingVaultState.transcribing ||
                                    controller.state ==
                                        WhisperingVaultState.loadingModel
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    controller.toggleRecording();
                                  },
                            icon: Icon(
                              controller.state == WhisperingVaultState.recording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _transcript(BuildContext context) {
    final mapping = controller.mapping;
    final transcript = controller.transcript;
    if (transcript.isEmpty) {
      return const Center(
        child: Text(
          'Tap the microphone and speak. Progressive transcription stays '
          'entirely on this device.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (mapping == null || mapping.transcriptNodes.isEmpty) {
      return SingleChildScrollView(
        child: Text(
          transcript,
          key: const Key('whisper-progressive-transcript'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return ListView(
      key: const Key('whisper-transcript-nodes'),
      children: [
        for (final sentence in mapping.transcriptNodes)
          _TranscriptSentence(
            sentence: sentence,
            onTap: onNodeSelected == null
                ? null
                : () => onNodeSelected!(sentence.nodeId),
          ),
      ],
    );
  }

  Widget _playbackControls() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        key: const Key('whisper-playback-toggle'),
        tooltip: controller.isPlaying ? 'Pause recording' : 'Play recording',
        onPressed: controller.togglePlayback,
        icon: Icon(
          controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
      ),
      for (final rate in const [1.0, 1.5, 2.0])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            key: Key('whisper-speed-${rate}x'),
            label: Text('${rate}x'),
            selected: controller.playbackRate == rate,
            onSelected: (_) => controller.setPlaybackRate(rate),
          ),
        ),
    ],
  );

  static String _status(WhisperingVaultState state) => switch (state) {
    WhisperingVaultState.idle => 'Ready for an air-gapped reflection',
    WhisperingVaultState.loadingModel => 'Loading embedded Whisper model…',
    WhisperingVaultState.recording => 'Listening and transcribing locally…',
    WhisperingVaultState.transcribing => 'Sealing audio and mapping concepts…',
    WhisperingVaultState.ready => 'Encrypted reflection ready',
    WhisperingVaultState.error => 'Offline processing paused',
  };
}

final class _TranscriptSentence extends StatelessWidget {
  const _TranscriptSentence({required this.sentence, this.onTap});

  final AudioTranscriptNode sentence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: Key('whisper-sentence-${sentence.nodeId}'),
      title: Text(sentence.sentence),
      trailing: onTap == null
          ? null
          : const Icon(Icons.center_focus_strong_outlined),
      onTap: onTap,
    ),
  );
}

final class _WhisperWaveformPainter extends CustomPainter {
  const _WhisperWaveformPainter({
    required this.values,
    required this.color,
    required this.active,
  });

  final List<double> values;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final values = this.values.isEmpty
        ? List<double>.generate(36, (index) => .08 + .03 * sin(index * .7))
        : this.values;
    final width = size.width / max(1, values.length);
    final paint = Paint()
      ..color = color.withValues(alpha: active ? .9 : .48)
      ..strokeWidth = max(2, width * .46)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < values.length; index++) {
      final height = max(4, values[index] * size.height * .82);
      final x = width * index + width / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WhisperWaveformPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.active != active;
}

final class _ParticleGlowPainter extends CustomPainter {
  const _ParticleGlowPainter({required this.waveform, required this.color});

  final List<double> waveform;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final energy = waveform.isEmpty
        ? .08
        : waveform.fold<double>(0, (sum, value) => sum + value) /
              waveform.length;
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withValues(alpha: .18 * energy),
              color.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .5, size.height * .55),
              radius: size.shortestSide * (.35 + energy * .2),
            ),
          );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ParticleGlowPainter oldDelegate) =>
      oldDelegate.waveform != waveform || oldDelegate.color != color;
}
