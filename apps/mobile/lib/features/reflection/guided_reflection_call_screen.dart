import 'dart:async';
import 'dart:math' as math;

import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:archiveme_mobile/features/audio/local_speech_synthesizer.dart';
import 'package:archiveme_mobile/features/reflection/reflection_prompts.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the full-screen call for a reflection notification payload.
abstract final class ReflectionCallLaunch {
  static bool matches(String? payload) =>
      ReflectionCallPayload.templateIdOf(payload) != null;

  static Future<void> open(
    BuildContext context, {
    required String title,
    Future<void> Function(String transcript)? onSave,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => GuidedReflectionCallScreen(
          promptTitle: title,
          onSave: onSave,
        ),
      ),
    );
  }
}

/// Full-screen voice reflection started from a proactive prompt.
class GuidedReflectionCallScreen extends ConsumerStatefulWidget {
  const GuidedReflectionCallScreen({
    required this.promptTitle,
    super.key,
    this.onSave,
  });

  final String promptTitle;
  final Future<void> Function(String transcript)? onSave;

  @override
  ConsumerState<GuidedReflectionCallScreen> createState() =>
      _GuidedReflectionCallScreenState();
}

class _GuidedReflectionCallScreenState
    extends ConsumerState<GuidedReflectionCallScreen> {
  var _showTranscript = false;
  var _saved = false;
  var _started = false;
  var _speakingReply = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void deactivate() {
    ref.read(localSpeechSynthesizerProvider.notifier).interrupt();
    super.deactivate();
  }

  Future<void> _begin() async {
    if (_started || !mounted) return;
    _started = true;
    final engine = ref.read(dualModeAudioEngineProvider.notifier);
    await ref.read(dualModeAudioEngineProvider.future);
    if (!mounted) return;
    await engine.selectMode(DualAudioMode.interactive);
    if (!mounted) return;
    await engine.start();
  }

  String _transcript(DualModeAudioSnapshot snapshot) {
    if (snapshot.turns.isEmpty) return snapshot.partialTranscript.trim();
    return snapshot.turns
        .map((turn) => turn.transcript.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  Future<void> _speakReply(String reply) async {
    if (!mounted) return;
    setState(() => _speakingReply = true);
    await ref
        .read(localSpeechSynthesizerProvider.notifier)
        .speakRouted(
          LlmRouter(local: (_) async => reply),
          workload: LlmWorkload.chatReply,
          prompt: reply,
        );
    if (!mounted) return;
    setState(() => _speakingReply = false);
  }

  Future<void> _save(DualModeAudioSnapshot snapshot) async {
    final transcript = _transcript(snapshot);
    await widget.onSave?.call(transcript);
    if (!mounted) return;
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dualModeAudioEngineProvider, (previous, next) {
      final reply = next.value?.lastReply;
      final prior = previous?.value?.lastReply;
      if (reply == null || reply.isEmpty || reply == prior) return;
      final spoken = reply;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_speakReply(spoken));
      });
    });
    final asyncSnapshot = ref.watch(dualModeAudioEngineProvider);
    final snapshot = asyncSnapshot.value ?? const DualModeAudioSnapshot();
    final playing = snapshot.playingResponse || _speakingReply;
    final listening = snapshot.recording && !playing;
    final transcript = _transcript(snapshot);

    return Scaffold(
      key: const Key('guided_reflection_call'),
      backgroundColor: AppTokens.neutral900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spacing6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.promptTitle,
                key: const Key('reflection_prompt_title'),
                style: ArchiveMobileTypography.responsivePageTitle(
                  context,
                ).copyWith(color: Colors.white),
              ),
              const Spacer(),
              _AmbientPulse(
                listening: listening,
                playing: playing,
              ),
              const SizedBox(height: AppTokens.spacing4),
              Text(
                playing ? 'Playing a response' : 'Listening',
                textAlign: TextAlign.center,
                style: ArchiveMobileTypography.responsiveSectionTitle(
                  context,
                ).copyWith(color: AppTokens.neutral200),
              ),
              const Spacer(),
              if (_saved)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppTokens.spacing3),
                  child: Text(
                    'Saved',
                    key: Key('reflection_saved'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              if (_showTranscript)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spacing3),
                  child: Text(
                    transcript.isEmpty
                        ? 'Transcription will appear here.'
                        : transcript,
                    key: const Key('reflection_transcript_panel'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    key: const Key('reflection_save'),
                    onPressed: () => unawaited(_save(snapshot)),
                    child: const Text('Save moment'),
                  ),
                  TextButton(
                    key: const Key('reflection_view_transcript'),
                    onPressed: () =>
                        setState(() => _showTranscript = !_showTranscript),
                    child: const Text('View transcription'),
                  ),
                  TextButton(
                    key: const Key('reflection_dismiss'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientPulse extends StatefulWidget {
  const _AmbientPulse({required this.listening, required this.playing});

  final bool listening;
  final bool playing;

  @override
  State<_AmbientPulse> createState() => _AmbientPulseState();
}

class _AmbientPulseState extends State<_AmbientPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening || widget.playing) unawaited(_pulse.repeat());
  }

  @override
  void didUpdateWidget(_AmbientPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final active = widget.listening || widget.playing;
    if (active && !_pulse.isAnimating) {
      unawaited(_pulse.repeat());
    } else if (!active && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.listening || widget.playing;
    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return CustomPaint(
            key: Key(
              widget.playing
                  ? 'reflection_playback_visualizer'
                  : 'reflection_listening_visualizer',
            ),
            painter: _PulsePainter(
              t: active ? _pulse.value : 0,
              color: widget.playing
                  ? AppTokens.primary200
                  : AppTokens.primary400,
            ),
            child: const SizedBox(width: 180, height: 120),
          );
        },
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const bars = 5;
    final slot = size.width / bars;
    for (var index = 0; index < bars; index++) {
      final wave = math.sin((t * math.pi * 2) + index);
      final height = 16 + ((wave + 1) / 2) * (size.height - 16);
      final rect = Rect.fromLTWH(
        index * slot + 8,
        (size.height - height) / 2,
        slot - 16,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}
