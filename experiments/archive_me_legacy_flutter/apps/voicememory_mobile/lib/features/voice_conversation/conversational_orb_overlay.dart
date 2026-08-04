import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/ui/voice/reactive_voice_orb.dart';
import 'conversation_ingestion_task.dart';
import 'voice_conversation_engine.dart';

class ConversationalOrbOverlay extends StatefulWidget {
  const ConversationalOrbOverlay({
    super.key,
    required this.controller,
    required this.onClosed,
    this.startAutomatically = true,
  });

  final VoiceConversationController controller;
  final VoidCallback onClosed;
  final bool startAutomatically;

  @override
  State<ConversationalOrbOverlay> createState() =>
      _ConversationalOrbOverlayState();
}

class _ConversationalOrbOverlayState extends State<ConversationalOrbOverlay> {
  late VoiceConversationState _state = widget.controller.state;
  StreamSubscription<VoiceConversationState>? _subscription;
  final _scrollController = ScrollController();
  VoiceConversationPhase? _announcedPhase;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      _announce(state.phase);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    });
    if (widget.startAutomatically) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(widget.controller.start());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  void _announce(VoiceConversationPhase phase) {
    if (_announcedPhase == phase) return;
    if (!MediaQuery.supportsAnnounceOf(context)) return;
    _announcedPhase = phase;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _phaseLabel(phase),
        Directionality.of(context),
      ),
    );
  }

  Future<void> _end() async {
    await widget.controller.stop();
    if (mounted) widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final phase = _state.phase;
    final level = phase == VoiceConversationPhase.speaking
        ? _state.outputLevel
        : _state.micLevel;
    return Positioned.fill(
      key: const Key('conversational_orb_overlay'),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Talk with your Memory Graph',
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('conversational_orb_dimmer'),
                  behavior: HitTestBehavior.opaque,
                  child: ColoredBox(color: Colors.black.withValues(alpha: .48)),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Chip(
                            key: const Key('conversational-orb-status-chip'),
                            avatar: Icon(_phaseIcon(phase), size: 18),
                            label: Text(_phaseLabel(phase)),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'End Memory Graph conversation',
                            onPressed: phase == VoiceConversationPhase.ending
                                ? null
                                : _end,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                liveRegion: true,
                                label: _phaseLabel(phase),
                                child: ReactiveVoiceOrb(
                                  key: const Key(
                                    'conversational_orb_visualizer',
                                  ),
                                  level: level,
                                  color: _phaseColor(phase),
                                  animate:
                                      !reduceMotion &&
                                      phase !=
                                          VoiceConversationPhase.disconnected,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _supportingCopy(phase),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              if (phase ==
                                  VoiceConversationPhase.searchingGraph)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Chip(
                                    key: Key(
                                      'conversational_orb_searching_graph_badge',
                                    ),
                                    avatar: Icon(Icons.hub_outlined),
                                    label: Text('Searching Graph...'),
                                  ),
                                ),
                              if (phase ==
                                  VoiceConversationPhase.permissionDenied)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: FilledButton.tonalIcon(
                                    key: const Key(
                                      'voice-conversation-open-settings',
                                    ),
                                    onPressed: openAppSettings,
                                    icon: const Icon(Icons.settings),
                                    label: const Text('Open Settings'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: .88),
                              child: SingleChildScrollView(
                                key: const Key('conversational_orb_transcript'),
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_state.transcript.isEmpty &&
                                        _state.partialAssistantText.isEmpty)
                                      const Text(
                                        'Your live conversation transcript will appear here.',
                                      ),
                                    for (final line in _state.transcript)
                                      _TranscriptLine(line: line),
                                    if (_state.partialAssistantText.isNotEmpty)
                                      _TranscriptLine(
                                        line: VoiceConversationTranscriptLine(
                                          role: VoiceConversationRole.assistant,
                                          text: _state.partialAssistantText,
                                          createdAt: DateTime.now(),
                                        ),
                                        partial: true,
                                      ),
                                    if (_state.errorMessage != null)
                                      Text(
                                        _state.errorMessage!,
                                        key: const Key(
                                          'conversational-orb-error',
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('conversational_orb_end_button'),
                        onPressed: phase == VoiceConversationPhase.ending
                            ? null
                            : _end,
                        icon: const Icon(Icons.call_end),
                        label: const Text('End conversation'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.line, this.partial = false});

  final VoiceConversationTranscriptLine line;
  final bool partial;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      label:
          '${line.role == VoiceConversationRole.user ? 'You' : 'ArchiveMe'} said ${line.text}',
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text:
                  '${line.role == VoiceConversationRole.user ? 'You' : 'ArchiveMe'}: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: partial ? '${line.text}…' : line.text),
          ],
        ),
      ),
    ),
  );
}

String _phaseLabel(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.disconnected => 'Disconnected',
  VoiceConversationPhase.connecting => 'Connecting securely',
  VoiceConversationPhase.listening => 'Listening',
  VoiceConversationPhase.thinking => 'Thinking',
  VoiceConversationPhase.searchingGraph => 'Searching your Memory Graph',
  VoiceConversationPhase.speaking => 'ArchiveMe is speaking',
  VoiceConversationPhase.ending => 'Saving conversation',
  VoiceConversationPhase.permissionDenied => 'Microphone permission needed',
  VoiceConversationPhase.error => 'Connection interrupted',
};

String _supportingCopy(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.searchingGraph =>
    'Your encrypted history is being searched locally.',
  VoiceConversationPhase.permissionDenied =>
    'Allow microphone access to begin a voice conversation.',
  VoiceConversationPhase.error =>
    'You can close this overlay and try again when ready.',
  VoiceConversationPhase.connecting => 'Creating a private ephemeral session…',
  VoiceConversationPhase.thinking => 'Connecting what you said…',
  VoiceConversationPhase.speaking =>
    'Listening is paused while ArchiveMe replies.',
  VoiceConversationPhase.ending => 'Encrypting and updating your graph…',
  VoiceConversationPhase.disconnected => 'The session has ended.',
  VoiceConversationPhase.listening =>
    'Speak naturally. You can interrupt at any time.',
};

IconData _phaseIcon(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.listening => Icons.mic,
  VoiceConversationPhase.speaking => Icons.graphic_eq,
  VoiceConversationPhase.searchingGraph => Icons.hub_outlined,
  VoiceConversationPhase.thinking => Icons.auto_awesome,
  VoiceConversationPhase.permissionDenied => Icons.mic_off,
  VoiceConversationPhase.error => Icons.cloud_off,
  VoiceConversationPhase.ending => Icons.lock,
  VoiceConversationPhase.connecting => Icons.cloud_sync,
  VoiceConversationPhase.disconnected => Icons.call_end,
};

Color _phaseColor(VoiceConversationPhase phase) => switch (phase) {
  VoiceConversationPhase.listening => const Color(0xFF6D5DFB),
  VoiceConversationPhase.speaking => const Color(0xFF20C997),
  VoiceConversationPhase.searchingGraph => const Color(0xFFFFB547),
  VoiceConversationPhase.error ||
  VoiceConversationPhase.permissionDenied => const Color(0xFFE5484D),
  _ => const Color(0xFF7C8DB5),
};
