import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/archive/controllers/on_this_day_controller.dart';
import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Home / Archive section — memory resurfacing cards.
class MemoryResurfacingSection extends StatelessWidget {
  const MemoryResurfacingSection({
    super.key,
    required this.cards,
    this.stats,
    required this.onCardTap,
  });

  final List<MemoryResurfacingCardData> cards;
  final MemoryResurfacingStats? stats;
  final ValueChanged<MemoryResurfacingCardData> onCardTap;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.resurfacingImplemented) return const SizedBox.shrink();
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'From your archive',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            if (stats != null)
              Text(
                'Shown ${stats!.resurfacedCount} · Opened ${stats!.openedCount}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemoryResurfacingCard(
              data: card,
              onTap: () => onCardTap(card),
            ),
          ),
        ),
      ],
    );
  }
}

/// Home / Archive section — "On this day" calendar-anniversary cards.
///
/// Surfaces recordings from previous years whose local month and day match
/// today. Complements [MemoryResurfacingSection]; these cards are un-rationed
/// and do not call [MemoryResurfacingService.markShown].
class OnThisDaySection extends StatelessWidget {
  const OnThisDaySection({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.now,
  });

  final List<MemoryResurfacingCardData> cards;
  final ValueChanged<MemoryResurfacingCardData> onCardTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.resurfacingImplemented) return const SizedBox.shrink();
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'On this day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'From past years on this date',
          style: TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
        const SizedBox(height: 10),
        ..._groupedCards(),
      ],
    );
  }

  List<Widget> _groupedCards() {
    final today = now ?? DateTime.now();
    final groups = OnThisDayController.group(
      entries: [for (final card in cards) card.entry],
      today: today,
    );
    if (groups.isEmpty) {
      return [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemoryResurfacingCard(
              data: card,
              onTap: () => onCardTap(card),
            ),
          ),
      ];
    }
    final byId = {for (final card in cards) card.entry.id: card};
    return [
      for (final label in groups.keys) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label, key: Key('on_this_day_section_$label')),
        ),
        for (final entry in groups[label]!)
          if (byId[entry.id] case final card?)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemoryResurfacingCard(
                data: card,
                onTap: () => onCardTap(card),
              ),
            ),
      ],
    ];
  }
}

class _MemoryResurfacingCard extends StatelessWidget {
  const _MemoryResurfacingCard({required this.data, required this.onTap});

  final MemoryResurfacingCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.headline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${data.quoteSnippet}"',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.originalDateLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              if (data.beliefRelation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  data.beliefRelation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
