import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform_controller.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Live capture waveform driven by [RecordingWaveformController].
///
/// Amplitude samples update the controller; a local ticker interpolates bar
/// heights and repaints via [CustomPaint] only — the parent widget tree is
/// not rebuilt on every frame.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({
    required this.controller,
    super.key,
    this.height = 52,
    this.color,
    this.semanticsLabel = 'Live audio waveform',
  });

  final RecordingWaveformController controller;
  final double height;
  final Color? color;
  final String semanticsLabel;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final RecordingWaveformRepaintNotifier _repaint;
  late List<double> _displayLevels;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _repaint = RecordingWaveformRepaintNotifier();
    _displayLevels = List<double>.from(widget.controller.levels);
    widget.controller.addListener(_handleControllerUpdate);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant RecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdate);
      widget.controller.addListener(_handleControllerUpdate);
      _displayLevels = List<double>.from(widget.controller.levels);
      _repaint.markNeedsPaint();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (_displayLevels.length != widget.controller.levels.length) {
      _displayLevels = List<double>.from(widget.controller.levels);
    }
    _repaint.markNeedsPaint();
  }

  void _onTick(Duration elapsed) {
    final targets = widget.controller.levels;
    if (targets.length != _displayLevels.length) {
      _displayLevels = List<double>.from(targets);
      _repaint.markNeedsPaint();
      return;
    }

    var dirty = false;
    for (var i = 0; i < _displayLevels.length; i++) {
      final delta = targets[i] - _displayLevels[i];
      if (delta.abs() <= 0.001) continue;
      _displayLevels[i] += delta * 0.32;
      dirty = true;
    }
    if (dirty) {
      _repaint.markNeedsPaint();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? VoiceMemoryColors.primaryIndigo;
    return Semantics(
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: RecordingWaveformPainter(
              repaint: _repaint,
              levels: _displayLevels,
              color: color,
            ),
            isComplex: true,
            willChange: true,
          ),
        ),
      ),
    );
  }
}