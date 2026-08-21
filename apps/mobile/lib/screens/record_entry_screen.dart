import 'dart:async';

import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_providers.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/widgets/evidence_insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal hold-to-record capture for the Evidence Method vertical slice.
class RecordEntryScreen extends ConsumerStatefulWidget {
  const RecordEntryScreen({super.key});

  @override
  ConsumerState<RecordEntryScreen> createState() => _RecordEntryScreenState();
}

class _RecordEntryScreenState extends ConsumerState<RecordEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recordEntrySessionNotifierProvider).setCaptureScreenAttached(true);
    });
  }

  @override
  void dispose() {
    ref.read(recordEntrySessionNotifierProvider).setCaptureScreenAttached(false);
    super.dispose();
  }

  Future<void> _confirmLeaveWhileRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recording in progress'),
        content: const Text(
          'Leave this screen? Your microphone stream is still active. '
          'Return here to finish, or cancel the recording first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave anyway'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(recordEntrySessionProvider);
    final notifier = ref.read(recordEntrySessionNotifierProvider);
    final theme = Theme.of(context);
    final phase = session.phase;

    return PopScope(
      canPop: !session.blocksBackNavigation,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !session.blocksBackNavigation) {
          return;
        }
        unawaited(_confirmLeaveWhileRecording());
      },
      child: Scaffold(
        backgroundColor: VoiceMemoryColors.background,
        appBar: AppBar(
          title: const Text('Record Entry'),
          backgroundColor: VoiceMemoryColors.background,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  _statusLabel(phase),
                  key: const Key('record_entry_status'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: VoiceMemoryColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusHint(phase, session.savedEncryptedAudioPath),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: VoiceMemoryColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const Spacer(),
                if (session.isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: CircularProgressIndicator(),
                  )
                else
                  _HoldToRecordButton(
                    enabled:
                        phase == RecordEntryPhase.idle ||
                        phase == RecordEntryPhase.complete ||
                        phase == RecordEntryPhase.error ||
                        phase == RecordEntryPhase.backgroundPaused,
                    isRecording:
                        phase == RecordEntryPhase.recording ||
                        phase == RecordEntryPhase.backgroundPaused,
                    onHoldStart: notifier.onHoldStarted,
                    onHoldEnd: notifier.onHoldEnded,
                    onHoldCancel: notifier.onHoldCanceled,
                  ),
                const Spacer(),
                if (session.errorMessage case final error?)
                  _ResultCard(
                    title: 'Something went wrong',
                    body: error,
                  )
                else if (session.insight case final insight?)
                  EvidenceInsightCard(
                    insight: Insight(
                      id: insight.id,
                      insightText: insight.insightText,
                      kind: _kindFromString(insight.kind),
                      confidenceBand: _bandFromString(insight.confidenceBand),
                      citedEntries: const [],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ArchiveInsightKind _kindFromString(String? kind) {
    return ArchiveInsightKind.values.asNameMap()[kind ?? ''] ??
        ArchiveInsightKind.theme;
  }

  PatternMatchConfidenceBand _bandFromString(String band) {
    return PatternMatchConfidenceBand.values.asNameMap()[band] ??
        PatternMatchConfidenceBand.weak;
  }

  String _statusLabel(RecordEntryPhase phase) {
    return switch (phase) {
      RecordEntryPhase.idle => 'Hold to Record',
      RecordEntryPhase.connecting => 'Connecting…',
      RecordEntryPhase.recording => 'Recording',
      RecordEntryPhase.backgroundPaused => 'Recording paused',
      RecordEntryPhase.processing => 'Finding evidence…',
      RecordEntryPhase.generatingInsight => 'Generating insight…',
      RecordEntryPhase.complete => 'Insight ready',
      RecordEntryPhase.error => 'Try again',
    };
  }

  String _statusHint(RecordEntryPhase phase, String? savedEncryptedAudioPath) {
    return switch (phase) {
      RecordEntryPhase.idle =>
        'Press and hold the button, speak naturally, then release.',
      RecordEntryPhase.connecting =>
        'Opening a live audio connection to the backend.',
      RecordEntryPhase.recording =>
        'Release when you are done. Audio streams in real time.',
      RecordEntryPhase.backgroundPaused =>
        savedEncryptedAudioPath == null
            ? 'Recording paused while the app was in the background. Hold to continue when you return.'
            : 'Your audio was saved securely while the app was in the background. Hold to continue recording.',
      RecordEntryPhase.processing =>
        'Matching your words against your archive and generating insight.',
      RecordEntryPhase.generatingInsight =>
        'Building your insight from retrieved evidence.',
      RecordEntryPhase.complete =>
        'Insight grounded in your transcript and retrieved history.',
      RecordEntryPhase.error =>
        'Check your microphone permission and backend connection.',
    };
  }
}

class _HoldToRecordButton extends StatelessWidget {
  const _HoldToRecordButton({
    required this.enabled,
    required this.isRecording,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onHoldCancel,
  });

  final bool enabled;
  final bool isRecording;
  final Future<void> Function() onHoldStart;
  final Future<void> Function() onHoldEnd;
  final Future<void> Function() onHoldCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Listener(
      key: const Key('record_entry_hold_button'),
      onPointerDown: enabled ? (_) => onHoldStart() : null,
      onPointerUp: isRecording ? (_) => onHoldEnd() : null,
      onPointerCancel: isRecording ? (_) => onHoldCancel() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isRecording ? 220 : 200,
        height: isRecording ? 220 : 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? scheme.error : VoiceMemoryColors.primaryIndigo,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? scheme.error : VoiceMemoryColors.primaryIndigo)
                  .withValues(alpha: 0.28),
              blurRadius: isRecording ? 28 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          isRecording ? 'Release' : 'Hold to Record',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: VoiceMemoryColors.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: VoiceMemoryColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}