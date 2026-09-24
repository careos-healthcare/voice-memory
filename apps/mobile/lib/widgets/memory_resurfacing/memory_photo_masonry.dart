import 'package:cached_network_image/cached_network_image.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Column count for the resurfacing photo grid.
///
/// Two columns on a phone. Three once the card is at least 600 logical pixels
/// wide, which covers the 13-inch canvas.
int memoryPhotoColumnCount(double width) => width >= 600 ? 3 : 2;

/// Non-scrolling masonry of attached stills.
///
/// The parent sliver owns scrolling, so this grid only lays out the photos
/// that belong to one card.
class MemoryPhotoMasonry extends StatelessWidget {
  const MemoryPhotoMasonry({required this.imageUrls, super.key});

  final List<String> imageUrls;

  static const _tileHeights = <double>[96, 128, 160];

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = memoryPhotoColumnCount(constraints.maxWidth);
        final buckets = List.generate(columns, (_) => <int>[]);
        for (var index = 0; index < imageUrls.length; index++) {
          buckets[index % columns].add(index);
        }
        final ink = Theme.of(context).colorScheme.onSurface;
        return Row(
          key: Key('memory_photo_grid_$columns'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  children: [
                    for (final index in buckets[column])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: CachedNetworkImage(
                          imageUrl: imageUrls[index],
                          height: _tileHeights[index % _tileHeights.length],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 480,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (context, url) => SizedBox(
                            height: _tileHeights[index % _tileHeights.length],
                            child: ColoredBox(
                              color: ink.withValues(alpha: 0.06),
                            ),
                          ),
                          errorWidget: (context, url, error) => SizedBox(
                            height: _tileHeights[index % _tileHeights.length],
                            child: ColoredBox(
                              color: ink.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
