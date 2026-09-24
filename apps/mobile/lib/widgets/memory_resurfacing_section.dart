import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing/memory_audio_wavebar.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing/memory_location_snippet.dart';
import 'package:archiveme_mobile/widgets/memory_resurfacing/memory_photo_masonry.dart';
import 'package:flutter/material.dart';

/// Home / Archive section — memory resurfacing cards.
class MemoryResurfacingSection extends StatelessWidget {
  const MemoryResurfacingSection({
    super.key,
    required this.cards,
    this.stats,
    required this.onCardTap,
    this.transportFactory,
  });

  final List<MemoryResurfacingCardData> cards;
  final MemoryResurfacingStats? stats;
  final ValueChanged<MemoryResurfacingCardData> onCardTap;
  final WavebarTransport Function(String audioPath)? transportFactory;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.resurfacingImplemented) return const SizedBox.shrink();
    if (cards.isEmpty) return const SizedBox.shrink();

    return CustomScrollView(
      primary: false,
      physics: memoryFeedScrollPhysics(Theme.of(context).platform),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          sliver: SliverMainAxisGroup(
            slivers: memoryResurfacingFeedSlivers(
              title: 'From your archive',
              cards: cards,
              stats: stats,
              onCardTap: onCardTap,
              transportFactory: transportFactory,
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
    this.transportFactory,
  });

  final List<MemoryResurfacingCardData> cards;
  final ValueChanged<MemoryResurfacingCardData> onCardTap;
  final WavebarTransport Function(String audioPath)? transportFactory;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.resurfacingImplemented) return const SizedBox.shrink();
    if (cards.isEmpty) return const SizedBox.shrink();

    return CustomScrollView(
      primary: false,
      physics: memoryFeedScrollPhysics(Theme.of(context).platform),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          sliver: SliverMainAxisGroup(
            slivers: memoryResurfacingFeedSlivers(
              title: 'On this day',
              subtitle: 'From past years on this date',
              cards: cards,
              onCardTap: onCardTap,
              transportFactory: transportFactory,
            ),
          ),
        ),
      ],
    );
  }
}

/// Platform scrolling for a feed that is its own [CustomScrollView].
ScrollPhysics memoryFeedScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    _ => const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  };
}

/// Slivers for one resurfacing feed. The archive home inserts these into its
/// existing [CustomScrollView] so photos, audio, and maps share one scroll.
List<Widget> memoryResurfacingFeedSlivers({
  required String title,
  required List<MemoryResurfacingCardData> cards,
  required ValueChanged<MemoryResurfacingCardData> onCardTap,
  String? subtitle,
  MemoryResurfacingStats? stats,
  WavebarTransport Function(String audioPath)? transportFactory,
}) {
  if (cards.isEmpty) return const [];
  return [
    SliverToBoxAdapter(
      child: _FeedHeader(title: title, subtitle: subtitle, stats: stats),
    ),
    SliverList.builder(
      addAutomaticKeepAlives: false,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = cards.indexWhere((card) => card.entry.id == key.value);
        return index < 0 ? null : index;
      },
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return RepaintBoundary(
          key: ValueKey(card.entry.id),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _MemoryResurfacingCard(
              data: card,
              onTap: () => onCardTap(card),
              transport: card.audioPath == null
                  ? null
                  : transportFactory?.call(card.audioPath!),
            ),
          ),
        );
      },
    ),
  ];
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.title, this.subtitle, this.stats});

  final String title;
  final String? subtitle;
  final MemoryResurfacingStats? stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
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
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryResurfacingCard extends StatelessWidget {
  const _MemoryResurfacingCard({
    required this.data,
    required this.onTap,
    required this.transport,
  });

  final MemoryResurfacingCardData data;
  final VoidCallback onTap;
  final WavebarTransport? transport;

  @override
  Widget build(BuildContext context) {
    final audioPath = data.audioPath;
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                '"${data.quoteSnippet}"',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (data.imageUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                MemoryPhotoMasonry(imageUrls: data.imageUrls),
              ],
              if (audioPath != null) ...[
                const SizedBox(height: AppSpacing.xs),
                MemoryAudioWavebar(audioPath: audioPath, transport: transport),
              ],
              if (data.place != null) ...[
                const SizedBox(height: AppSpacing.sm),
                MemoryLocationSnippet(place: data.place!),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                data.originalDateLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              if (data.beliefRelation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
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
