import 'dart:async';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/features/voice/data/voice_call_service.dart';
import 'package:archiveme_mobile/features/voice/data/voice_journal_pipeline.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';

/// Hands-free call. The orb follows the louder of the mic and the reply.
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({
    super.key,
    this.service,
    this.pipeline,
  });

  final VoiceCallService? service;
  final VoiceJournalPipeline? pipeline;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late final VoiceCallService _service =
      widget.service ??
      VoiceCallService(
        transport: LoopbackVoiceTransport(),
        capture: ManualVoiceCapture(),
      );
  late final VoiceJournalPipeline _pipeline =
      widget.pipeline ??
      VoiceJournalPipeline(
        save: _saveToJournal,
        index: _indexLifePatterns,
      );

  double _input = 0;
  double _output = 0;
  String _transcript = '';
  List<String> _patterns = const [];
  var _saved = false;
  StreamSubscription<double>? _inputSub;
  StreamSubscription<double>? _outputSub;
  StreamSubscription<String>? _partials;

  @override
  void initState() {
    super.initState();
    _inputSub = _service.inputLevel.listen((level) {
      if (!mounted) return;
      setState(() => _input = level);
    });
    _outputSub = _service.outputLevel.listen((level) {
      if (!mounted) return;
      setState(() => _output = level);
    });
    _partials = _service.partials.listen((_) {
      if (!mounted) return;
      setState(() => _transcript = _service.transcript);
    });
    unawaited(_service.start());
  }

  @override
  void dispose() {
    unawaited(_inputSub?.cancel());
    unawaited(_outputSub?.cancel());
    unawaited(_partials?.cancel());
    if (_service.isConnected) {
      unawaited(_service.end());
    }
    super.dispose();
  }

  Future<void> _saveToJournal(JournalEntry entry) async {
    try {
      final store = appProviderContainer.read(journalStoreHolderProvider).value;
      if (store == null) return;
      await store.save(
        entry,
        first25Source: 'voice_call',
        captureKind: 'voice_call',
      );
    } on Object {
      // The transcript stays on screen when the journal is not open yet.
    }
  }

  Future<void> _indexLifePatterns(
    JournalEntry entry,
    List<String> lifePatterns,
  ) async {
    final index = VoiceInsightHooks.index;
    if (index == null) return;
    await index(entry, lifePatterns);
  }

  Future<void> _end() async {
    final transcript = await _service.end();
    final result = await _pipeline.complete(transcript);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _transcript = result.entry.transcript;
      _patterns = result.lifePatterns;
    });
  }

  @override
  Widget build(BuildContext context) {
    final energy = _input > _output ? _input : _output;
    return Scaffold(
      key: const Key('voice_call_screen'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Transform.scale(
                key: const Key('voice_call_orb'),
                scale: 1 + energy * 0.35,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF7F1EA),
                        Color(0xFFE7F0F4),
                        Color(0xFFF3E8F2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x143E4A55),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _service.isConnected ? 'Listening' : 'Call ended',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _transcript,
                    key: const Key('voice_call_transcript'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (_patterns.isNotEmpty)
                Text(
                  'Life Patterns: ${_patterns.join(' · ')}',
                  key: const Key('voice_call_life_patterns'),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (!_saved)
                FilledButton(
                  key: const Key('voice_call_end'),
                  onPressed: () => unawaited(_end()),
                  child: const Text('End call'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
