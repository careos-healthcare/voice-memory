import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../autonomous_muse_models.dart';
import '../legacy_sweep_orchestrator.dart';
import '../thematic_triage.dart';
import 'triage_card_stack.dart';

final class MuseDigestSheet extends StatefulWidget {
  const MuseDigestSheet({super.key, required this.controller});

  final LegacySweepController controller;

  static Future<void> show({
    required BuildContext context,
    required LegacySweepController controller,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: '/legacy-muse-digest',
    builder: (_) => MuseDigestSheet(controller: controller),
  );

  @override
  State<MuseDigestSheet> createState() => _MuseDigestSheetState();
}

class _MuseDigestSheetState extends State<MuseDigestSheet> {
  StreamSubscription<LegacySweepProgress>? _subscription;
  late LegacySweepProgress _progress;
  late List<ThematicDeck> _decks;
  int _deckIndex = 0;
  bool _showDeepConnections = false;

  @override
  void initState() {
    super.initState();
    _refresh(widget.controller.currentProgress);
    _subscription = widget.controller.progress.listen((progress) {
      if (mounted) setState(() => _refresh(progress));
    });
  }

  void _refresh(LegacySweepProgress progress) {
    _progress = progress;
    _decks = widget.controller.thematicDecks(
      includeDeepConnections: _showDeepConnections,
    );
    if (_deckIndex >= _decks.length) _deckIndex = 0;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _accept(LegacyBridgeSuggestion suggestion) async {
    await widget.controller.accept(suggestion.id);
    if (mounted) setState(() => _refresh(_progress));
  }

  Future<void> _reject(LegacyBridgeSuggestion suggestion) async {
    await widget.controller.reject(suggestion.id);
    if (mounted) setState(() => _refresh(_progress));
  }

  Future<void> _defer(LegacyBridgeSuggestion suggestion) async {
    await widget.controller.defer(suggestion.id);
    if (mounted) setState(() => _refresh(_progress));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Muse Legacy Digest'),
            subtitle: const Text('Private semantic bridges awaiting approval'),
            trailing: IconButton(
              key: const Key('muse-digest-close'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                GlassmorphicContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _statusLabel(_progress.status),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        key: const Key('muse-digest-progress'),
                        value: _progress.fraction,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          _DigestMetric(
                            key: const Key('muse-digest-analyzed'),
                            label: 'Nodes Analyzed',
                            value:
                                '${_progress.analyzedNodes}/${_progress.totalNodes}',
                          ),
                          _DigestMetric(
                            key: const Key('muse-digest-forged'),
                            label: 'Connections Forged',
                            value: '${_progress.connectionsForged}',
                          ),
                          _DigestMetric(
                            key: const Key('muse-digest-eta'),
                            label: 'Est. Time',
                            value: _duration(_progress.estimatedRemaining),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  key: const Key('muse-deep-connections-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deep Connections'),
                  subtitle: const Text(
                    'Include lower-confidence fringe bridges',
                  ),
                  value: _showDeepConnections,
                  onChanged: (value) => setState(() {
                    _showDeepConnections = value;
                    _deckIndex = 0;
                    _refresh(_progress);
                  }),
                ),
                if (_decks.isNotEmpty) ...[
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _decks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final deck = _decks[index];
                        return ChoiceChip(
                          key: Key('muse-deck-${deck.id}'),
                          selected: index == _deckIndex,
                          onSelected: (_) => setState(() => _deckIndex = index),
                          label: Text(
                            '${deck.suggestions.length} in ${deck.topic}',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_decks.isEmpty)
                  const GlassmorphicContainer(
                    key: Key('muse-digest-empty'),
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Today’s triage is complete. Remaining bridges stay '
                      'quietly in the backlog for a future digest.',
                    ),
                  )
                else
                  TriageCardStack(
                    key: ValueKey(
                      'triage-${_decks[_deckIndex].id}-'
                      '$_showDeepConnections',
                    ),
                    suggestions: _decks[_deckIndex].suggestions,
                    onAccept: _accept,
                    onReject: _reject,
                    onDefer: _defer,
                  ),
                const SizedBox(height: 10),
                Text(
                  '${widget.controller.backlogCount(includeDeepConnections: _showDeepConnections)} '
                  'bridges remain quietly in backlog.',
                  key: const Key('muse-digest-backlog'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(LegacySweepStatus status) => switch (status) {
    LegacySweepStatus.idle => 'Waiting for a legacy import',
    LegacySweepStatus.queued => 'Sweep queued locally',
    LegacySweepStatus.running => 'Muse is digesting imported notes',
    LegacySweepStatus.pausedThermal => 'Paused while the device cools',
    LegacySweepStatus.completed => 'Legacy sweep complete',
    LegacySweepStatus.failed => 'Sweep paused after a local error',
  };

  static String _duration(Duration? value) {
    if (value == null) return '—';
    if (value.inMinutes > 0) return '${value.inMinutes}m';
    return '${value.inSeconds}s';
  }
}

final class _DigestMetric extends StatelessWidget {
  const _DigestMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
