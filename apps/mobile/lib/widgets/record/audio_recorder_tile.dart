import 'dart:async';

import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Switches one capture session between a passive note and a live reflection.
class AudioRecorderTile extends ConsumerWidget {
  const AudioRecorderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(dualModeAudioEngineProvider);
    return engine.when(
      loading: () => const SizedBox(
        key: Key('audio_recorder_tile_loading'),
        height: 48,
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppTokens.spacing4),
        child: Text('Could not open the recorder: $error'),
      ),
      data: (snapshot) => _AudioRecorderBody(snapshot: snapshot),
    );
  }
}

class _AudioRecorderBody extends ConsumerWidget {
  const _AudioRecorderBody({required this.snapshot});

  final DualModeAudioSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dualModeAudioEngineProvider.notifier);
    final reply = snapshot.lastReply;
    return Material(
      key: const Key('audio_recorder_tile'),
      color: AppTokens.neutral50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.spacing3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spacing4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recording', style: AppTokens.card()),
            const SizedBox(height: AppTokens.spacing3),
            Wrap(
              spacing: AppTokens.spacing2,
              runSpacing: AppTokens.spacing2,
              children: [
                for (final mode in DualAudioMode.values)
                  ChoiceChip(
                    key: Key('audio_recorder_mode_${mode.name}'),
                    label: Text(mode.label, style: AppTokens.caption()),
                    selected: snapshot.mode == mode,
                    onSelected: (_) {
                      unawaited(notifier.selectMode(mode));
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spacing3),
            FilledButton(
              key: const Key('audio_recorder_toggle'),
              onPressed: snapshot.playingResponse
                  ? null
                  : () {
                      if (snapshot.recording) {
                        unawaited(notifier.stop());
                      } else {
                        unawaited(notifier.start());
                      }
                    },
              child: Text(snapshot.recording ? 'Stop' : 'Record'),
            ),
            if (snapshot.playingResponse) ...[
              const SizedBox(height: AppTokens.spacing2),
              Text(
                'Playing a reply. Recording stays open.',
                key: const Key('audio_recorder_playing'),
                style: AppTokens.caption(color: AppTokens.primary700),
              ),
            ],
            if (snapshot.partialTranscript.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spacing3),
              Text(
                snapshot.partialTranscript,
                key: const Key('audio_recorder_transcript'),
                style: snapshot.mode == DualAudioMode.interactive
                    ? AppTokens.body()
                    : AppTokens.writing(),
              ),
            ],
            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spacing2),
              Text(
                reply,
                key: const Key('audio_recorder_reply'),
                style: AppTokens.body(color: AppTokens.primary700),
              ),
            ],
            if (snapshot.error != null) ...[
              const SizedBox(height: AppTokens.spacing2),
              Text(
                snapshot.error!,
                key: const Key('audio_recorder_error'),
                style: AppTokens.caption(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
