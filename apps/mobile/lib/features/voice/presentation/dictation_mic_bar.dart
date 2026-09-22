import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Live speech partials and microphone level for the entry field.
abstract class DictationEngine {
  Future<void> start();
  Future<void> stop();
  Stream<String> get partials;
  Stream<double> get levels;
}

/// Writes recognizer text into the field that was focused when listening began.
class DictationSession extends ChangeNotifier {
  DictationSession({
    required this.engine,
    this.haptic = HapticFeedback.lightImpact,
  });

  final DictationEngine engine;
  final void Function() haptic;

  var listening = false;
  var _disposed = false;
  double level = 0;
  String _prefix = '';
  StreamSubscription<String>? _partials;
  StreamSubscription<double>? _levels;

  Future<void> toggle(TextEditingController controller) async {
    haptic();
    if (listening) {
      await stop();
      return;
    }
    _prefix = controller.text;
    if (_prefix.isNotEmpty && !_prefix.endsWith(' ')) {
      _prefix = '$_prefix ';
    }
    listening = true;
    notifyListeners();
    _partials = engine.partials.listen((partial) {
      final next = '$_prefix${partial.trim()}';
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });
    _levels = engine.levels.listen((value) {
      level = value.clamp(0, 1).toDouble();
      notifyListeners();
    });
    try {
      await engine.start();
    } on Object {
      await stop();
    }
  }

  Future<void> stop({bool notify = true}) async {
    final wasListening = listening;
    listening = false;
    level = 0;
    final partials = _partials;
    final levels = _levels;
    _partials = null;
    _levels = null;
    if (notify && !_disposed) notifyListeners();
    unawaited(partials?.cancel());
    unawaited(levels?.cancel());
    if (wasListening) {
      try {
        await engine.stop();
      } on Object {
        // Stopping a denied mic should still leave the field as it is.
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop(notify: false));
    super.dispose();
  }
}

/// Pulsing mic and sound bars for the main entry field.
class DictationMicBar extends StatefulWidget {
  const DictationMicBar({
    required this.controller,
    required this.engine,
    super.key,
    this.onVoiceCall,
    this.haptic = HapticFeedback.lightImpact,
  });

  final TextEditingController controller;
  final DictationEngine engine;
  final VoidCallback? onVoiceCall;
  final void Function() haptic;

  @override
  State<DictationMicBar> createState() => _DictationMicBarState();
}

class _DictationMicBarState extends State<DictationMicBar>
    with SingleTickerProviderStateMixin {
  late final DictationSession _session = DictationSession(
    engine: widget.engine,
    haptic: widget.haptic,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _pulse.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        if (_session.listening) {
          if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
        } else if (_pulse.isAnimating) {
          _pulse.stop();
          _pulse.value = 0;
        }
        return Row(
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.12).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: IconButton(
                key: const Key('dictation_mic_button'),
                tooltip: _session.listening ? 'Stop dictation' : 'Dictate',
                onPressed: () => unawaited(_session.toggle(widget.controller)),
                icon: Icon(
                  _session.listening ? Icons.mic : Icons.mic_none,
                ),
              ),
            ),
            if (_session.listening)
              Expanded(
                child: _SoundBars(
                  key: const Key('dictation_sound_bars'),
                  level: _session.level,
                ),
              )
            else
              const Spacer(),
            if (widget.onVoiceCall != null)
              TextButton(
                key: const Key('open_voice_call'),
                onPressed: widget.onVoiceCall,
                child: const Text('Voice call'),
              ),
          ],
        );
      },
    );
  }
}

class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.level, super.key});

  final double level;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 12; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  height: 6 + 22 * level * (0.45 + 0.55 * _wave(i, level)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _wave(int index, double level) {
    return (math.sin((index + level * 6) * 0.8) + 1) / 2;
  }
}
