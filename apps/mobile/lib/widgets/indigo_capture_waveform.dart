import 'dart:math' as math;

import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Subtle indigo bars — "capturing thoughts" while recording.
class IndigoCaptureWaveform extends StatefulWidget {
  const IndigoCaptureWaveform({super.key, this.barCount = 12});

  final int barCount;

  @override
  State<IndigoCaptureWaveform> createState() => _IndigoCaptureWaveformState();
}

class _IndigoCaptureWaveformState extends State<IndigoCaptureWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recording waveform',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.barCount, (i) {
                final phase = (_controller.value * 2 * math.pi) + (i * 0.55);
                final h = 8 + (math.sin(phase).abs() * 20);
                return Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: VoiceMemoryColors.primaryIndigo.withValues(
                      alpha: 0.45 + (i % 3) * 0.12,
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