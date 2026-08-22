import 'package:archiveme_mobile/core/di/audio_processing_queue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Activates the recording-completion listener for the audio processing queue.
class AudioProcessingQueueListenerHost extends ConsumerWidget {
  const AudioProcessingQueueListenerHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioProcessingQueueListenerProvider);
    return child;
  }
}
