import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/journal_playback/rich_memory_playback.dart';
import '../../services/hallucination_guard/hallucination_guard_service.dart';

String citationHeroTag(VerifiableCitation citation) =>
    'citation-${citation.sourceEntryId}-${citation.audioTimestampMs ?? 0}';

Future<bool> openCitationPlayback(
  BuildContext context, {
  required VerifiableCitation citation,
  required HallucinationGuardService guard,
}) async {
  final verification = await guard.verify(citation);
  if (!context.mounted ||
      verification.state == CitationVerificationState.flagged) {
    return false;
  }
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CitationPlaybackSheet(verification: verification),
  );
  return true;
}

class CitationPlaybackIntent {
  const CitationPlaybackIntent({
    required this.sourceEntryId,
    required this.audioTimestampMs,
  });

  final String sourceEntryId;
  final int? audioTimestampMs;
}

class CitationPlaybackWidget extends StatelessWidget {
  const CitationPlaybackWidget({
    super.key,
    required this.citation,
    required this.guard,
    this.onPlaybackIntent,
  });

  final VerifiableCitation citation;
  final HallucinationGuardService guard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  Widget build(BuildContext context) => FutureBuilder<CitationVerification>(
    future: guard.verify(citation),
    builder: (context, snapshot) {
      final verification = snapshot.data;
      final state = verification?.state ?? CitationVerificationState.flagged;
      final color = switch (state) {
        CitationVerificationState.verifiedQuote => Colors.green,
        CitationVerificationState.paraphrased => Colors.amber,
        CitationVerificationState.flagged => Colors.red,
      };
      final icon = switch (state) {
        CitationVerificationState.verifiedQuote => Icons.verified,
        CitationVerificationState.paraphrased => Icons.warning_amber_rounded,
        CitationVerificationState.flagged => Icons.flag_outlined,
      };
      final enabled =
          verification != null &&
          state != CitationVerificationState.flagged &&
          !snapshot.hasError;
      return Semantics(
        button: enabled,
        label: '${state.label}: ${citation.exactQuote}',
        child: Hero(
          tag: citationHeroTag(citation),
          child: Material(
            color: color.withValues(alpha: .08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color),
            ),
            child: InkWell(
              key: Key('citation_${citation.sourceEntryId}'),
              borderRadius: BorderRadius.circular(16),
              onTap: !enabled ? null : () => _open(context, verification),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text('“${citation.exactQuote}”'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  void _open(BuildContext context, CitationVerification verification) {
    if (verification.state == CitationVerificationState.verifiedQuote) {
      final intent = CitationPlaybackIntent(
        sourceEntryId: citation.sourceEntryId,
        audioTimestampMs: citation.audioTimestampMs,
      );
      if (onPlaybackIntent case final callback?) {
        callback(intent);
        return;
      }
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CitationPlaybackSheet(verification: verification),
      ),
    );
  }
}

class CitationPlaybackSheet extends StatefulWidget {
  const CitationPlaybackSheet({
    super.key,
    required this.verification,
    this.controller,
  });

  final CitationVerification verification;
  final MemoryPlaybackController? controller;

  @override
  State<CitationPlaybackSheet> createState() => _CitationPlaybackSheetState();
}

class _CitationPlaybackSheetState extends State<CitationPlaybackSheet> {
  late final MemoryPlaybackController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MemoryPlaybackController();
    final entry = widget.verification.sourceEntry;
    if (entry != null) {
      _controller.load(entry);
      if (widget.verification.state ==
          CitationVerificationState.verifiedQuote) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            _controller.playFrom(
              Duration(
                milliseconds:
                    widget.verification.citation.audioTimestampMs ?? 0,
              ),
            ),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.verification.sourceEntry;
    return Padding(
      key: const Key('citation_playback_sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: ListView(
        shrinkWrap: true,
        children: [
          Hero(
            tag: citationHeroTag(widget.verification.citation),
            child: Material(
              color: Colors.transparent,
              child: Text(
                widget.verification.state.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.verification.surroundingContext ?? 'Context unavailable.',
          ),
          const SizedBox(height: 16),
          if (entry?.localAudioReference?.isNotEmpty == true)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                children: [
                  IconButton(
                    key: const Key('citation_playback_toggle'),
                    tooltip: _controller.isPlaying
                        ? 'Pause quote'
                        : 'Play quote',
                    onPressed: () => unawaited(_controller.toggle()),
                    icon: Icon(
                      _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(value: _controller.progress),
                  ),
                ],
              ),
            )
          else
            const Text('Original audio is not available on this device.'),
        ],
      ),
    );
  }
}
