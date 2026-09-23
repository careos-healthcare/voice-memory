import 'dart:async';

import 'package:archiveme_mobile/features/onboarding/onboarding_router.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Local reply for the trial. Nothing is sent off the device.
String synthesizeTrialReflection(String transcript) {
  final words = transcript.trim();
  if (words.isEmpty) {
    return 'Say a few words about this moment. They stay on this screen for the trial.';
  }
  return 'Heard that. "$words" stays here for the trial and is not saved yet.';
}

/// Thirty-second guided reflection with on-device voice-to-text and a reply.
class TrialVoiceEntryScreen extends StatefulWidget {
  const TrialVoiceEntryScreen({
    super.key,
    this.transcribe,
    this.synthesize = synthesizeTrialReflection,
    this.onTrialCompleted,
    this.onContinue,
    this.onSaveBeyondBounds,
  });

  /// Optional on-device speech callback. Typing is always available.
  final Future<String> Function()? transcribe;

  final String Function(String transcript) synthesize;
  final VoidCallback? onTrialCompleted;
  final VoidCallback? onContinue;
  final VoidCallback? onSaveBeyondBounds;

  @override
  State<TrialVoiceEntryScreen> createState() => _TrialVoiceEntryScreenState();
}

class _TrialVoiceEntryScreenState extends State<TrialVoiceEntryScreen> {
  final _text = TextEditingController();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  var _completed = false;
  String _synthesis = synthesizeTrialReflection('');

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _tick() {
    if (_completed) return;
    _elapsed += const Duration(seconds: 1);
    if (OnboardingRouter.trialWindowClosed(_elapsed)) {
      _complete();
      return;
    }
    if (mounted) setState(() {});
  }

  void _applyTranscript(String value) {
    _text.text = value;
    _synthesis = widget.synthesize(value);
    if (mounted) setState(() {});
  }

  Future<void> _speak() async {
    final transcribe = widget.transcribe;
    if (transcribe == null || _completed) return;
    _applyTranscript(await transcribe());
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _ticker?.cancel();
    _synthesis = widget.synthesize(_text.text);
    if (mounted) setState(() {});
    widget.onTrialCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = OnboardingRouter.trialLimit - _elapsed;
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A short reflection',
            key: const Key('trial_voice_title'),
            style: AppTokens.section(),
          ),
          const SizedBox(height: AppTokens.spacing3),
          Text(
            'For 30 seconds, say what is on your mind. No account is required.',
            key: const Key('trial_voice_prompt'),
            style: AppTokens.body(),
          ),
          const SizedBox(height: AppTokens.spacing4),
          Text(
            '$seconds seconds left',
            key: const Key('trial_voice_remaining'),
            style: AppTokens.caption(),
          ),
          const SizedBox(height: AppTokens.spacing4),
          TextField(
            key: const Key('trial_voice_field'),
            controller: _text,
            enabled: !_completed,
            minLines: 3,
            maxLines: 5,
            style: AppTokens.writing(),
            decoration: const InputDecoration(
              hintText: 'Speak or type this moment',
            ),
            onChanged: _applyTranscript,
          ),
          const SizedBox(height: AppTokens.spacing3),
          if (widget.transcribe != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('trial_voice_speak'),
                onPressed: _completed ? null : _speak,
                child: const Text('Use voice'),
              ),
            ),
          Text(
            _synthesis,
            key: const Key('trial_voice_synthesis'),
            style: AppTokens.body(color: AppTokens.primary700),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('trial_voice_finish'),
            onPressed: _completed ? widget.onContinue : _complete,
            child: Text(_completed ? 'Continue' : 'Finish trial'),
          ),
          const SizedBox(height: AppTokens.spacing2),
          OutlinedButton(
            key: const Key('trial_voice_save'),
            onPressed: widget.onSaveBeyondBounds,
            child: const Text('Save this moment'),
          ),
        ],
      ),
    );
  }
}
