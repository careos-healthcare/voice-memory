import 'dart:math' as math;

import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Animated reply waveform — bar speed and height scale with playback queue depth.
class LiveVoiceSpeakingWaveform extends StatefulWidget {
  const LiveVoiceSpeakingWaveform({
    required this.queueDepth, super.key,
    this.barCount = 12,
  });

  final int queueDepth;
  final int barCount;

  @override
  State<LiveVoiceSpeakingWaveform> createState() =>
      _LiveVoiceSpeakingWaveformState();
}

class _LiveVoiceSpeakingWaveformState extends State<LiveVoiceSpeakingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void didUpdateWidget(LiveVoiceSpeakingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    final depth = widget.queueDepth.clamp(0, 4);
    final ms = switch (depth) {
      0 => 1100,
      1 => 850,
      2 => 650,
      _ => 480,
    };
    _controller.duration = Duration(milliseconds: ms);
    if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depth = widget.queueDepth.clamp(0, 4);
    final amplitudeBoost = depth * 4.0;

    return Semantics(
      label: 'Model reply waveform',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.barCount, (i) {
                final phase =
                    (_controller.value * 2 * math.pi) + (i * 0.55) + depth;
                final h = 8 + (math.sin(phase).abs() * (18 + amplitudeBoost));
                return Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: VoiceMemoryColors.captureSuccess.withValues(
                      alpha: 0.45 + (i % 3) * 0.12 + (depth * 0.04),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}