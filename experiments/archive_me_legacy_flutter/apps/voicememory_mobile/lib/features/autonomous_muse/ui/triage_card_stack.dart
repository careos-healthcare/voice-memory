import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../autonomous_muse_models.dart';

typedef TriageSuggestionAction =
    Future<void> Function(LegacyBridgeSuggestion suggestion);

final class TriageCardStack extends StatefulWidget {
  const TriageCardStack({
    super.key,
    required this.suggestions,
    required this.onAccept,
    required this.onReject,
    required this.onDefer,
  });

  final List<LegacyBridgeSuggestion> suggestions;
  final TriageSuggestionAction onAccept;
  final TriageSuggestionAction onReject;
  final TriageSuggestionAction onDefer;

  @override
  State<TriageCardStack> createState() => _TriageCardStackState();
}

class _TriageCardStackState extends State<TriageCardStack> {
  late List<LegacyBridgeSuggestion> _cards;
  Offset _drag = Offset.zero;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.suggestions);
  }

  @override
  void didUpdateWidget(TriageCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions && !_resolving) {
      _cards = List.of(widget.suggestions);
    }
  }

  Future<void> _resolve(_TriageDirection direction) async {
    if (_resolving || _cards.isEmpty) return;
    final card = _cards.first;
    setState(() => _resolving = true);
    switch (direction) {
      case _TriageDirection.accept:
        await widget.onAccept(card);
      case _TriageDirection.reject:
        await widget.onReject(card);
      case _TriageDirection.defer:
        await widget.onDefer(card);
    }
    if (!mounted) return;
    setState(() {
      _cards.removeAt(0);
      _drag = Offset.zero;
      _resolving = false;
    });
  }

  void _finishDrag() {
    if (_drag.dy < -90 && _drag.dy.abs() > _drag.dx.abs()) {
      _resolve(_TriageDirection.defer);
    } else if (_drag.dx > 110) {
      _resolve(_TriageDirection.accept);
    } else if (_drag.dx < -110) {
      _resolve(_TriageDirection.reject);
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return const GlassmorphicContainer(
        key: Key('triage-stack-empty'),
        padding: EdgeInsets.all(20),
        child: Text('This deck is complete.'),
      );
    }
    final visible = _cards.take(3).toList();
    return SizedBox(
      key: const Key('triage-card-stack'),
      height: 430,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          for (
            var reverseIndex = visible.length - 1;
            reverseIndex >= 0;
            reverseIndex--
          )
            _positionedCard(visible[reverseIndex], reverseIndex),
        ],
      ),
    );
  }

  Widget _positionedCard(LegacyBridgeSuggestion suggestion, int index) {
    final isTop = index == 0;
    final scale = 1 - (index * .035);
    final top = index * 14.0;
    final transform = Matrix4.identity();
    if (isTop) {
      transform
        ..translateByDouble(_drag.dx, _drag.dy, 0, 1)
        ..rotateZ(_drag.dx / 1800);
    } else {
      transform
        ..translateByDouble(0, top, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    }
    return AnimatedContainer(
      key: Key('triage-card-${suggestion.id}'),
      duration: _drag == Offset.zero
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      transform: transform,
      transformAlignment: Alignment.topCenter,
      child: IgnorePointer(
        ignoring: !isTop || _resolving,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => setState(() => _drag += details.delta),
          onPanEnd: (_) => _finishDrag(),
          child: _TriageCard(suggestion: suggestion),
        ),
      ),
    );
  }
}

enum _TriageDirection { accept, reject, defer }

final class _TriageCard extends StatelessWidget {
  const _TriageCard({required this.suggestion});

  final LegacyBridgeSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${suggestion.sourceLabel} ↔ ${suggestion.targetLabel}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _Snippet(
                    label: suggestion.sourceLabel,
                    text: suggestion.sourceExcerpt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Snippet(
                    label: suggestion.targetLabel,
                    text: suggestion.targetExcerpt,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            key: const Key('triage-mini-graph'),
            height: 78,
            child: CustomPaint(
              painter: BridgeMiniGraphPainter(
                confidence: suggestion.confidenceScore,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(suggestion.rationale, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            '← Reject   ↑ Tomorrow   Accept →',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

final class _Snippet extends StatelessWidget {
  const _Snippet({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              text.isEmpty ? 'No excerpt available' : text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

final class BridgeMiniGraphPainter extends CustomPainter {
  const BridgeMiniGraphPainter({required this.confidence});

  final double confidence;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Offset(size.width * .2, size.height * .5);
    final right = Offset(size.width * .8, size.height * .5);
    final color = Colors.tealAccent.withValues(alpha: .85);
    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = color
        ..strokeWidth = 1.5 + (confidence.clamp(0, 1) * 3),
    );
    for (final point in [left, right]) {
      canvas.drawCircle(
        point,
        math.min(size.width, size.height) * .13,
        Paint()..color = color,
      );
      canvas.drawCircle(
        point,
        math.min(size.width, size.height) * .07,
        Paint()..color = Colors.black.withValues(alpha: .45),
      );
    }
  }

  @override
  bool shouldRepaint(BridgeMiniGraphPainter oldDelegate) =>
      oldDelegate.confidence != confidence;
}
