import 'package:flutter/material.dart';

import '../../features/pattern_map/pattern_map_model.dart';
import '../../features/archive_memory/memory_quality_engine.dart';
import '../../features/archive_memory/memory_quality_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import 'memory_quality_chip.dart';

/// One clear map of a recurring pattern: how often it shows up, when it starts,
/// how it feels, what makes it lighter or heavier, and the next useful check.
class PatternMapCard extends StatelessWidget {
  const PatternMapCard({
    super.key,
    required this.map,
    this.onUseCheck,
    this.showTitle = true,
    this.quality,
  });

  final PatternMap map;

  /// Fires with the next check question when the user taps "Use this check".
  final void Function(String nextCheck)? onUseCheck;

  /// When false the "Pattern map" heading is hidden (e.g. under an app bar).
  final bool showTitle;

  /// When set, replaces the map confidence label with a quality chip.
  final MemoryQuality? quality;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    final quality = this.quality ?? buildMemoryQuality(map: map);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              'Pattern map',
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              ConsumerUiCopy.positioningClearerEachCheck,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            map.patternTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          if (quality.shouldShow)
            MemoryQualityChip(quality: quality)
          else
            Text(
              map.confidenceLabel,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
          const SizedBox(height: AppSpacing.md),
          _section('Seen', _seenLine()),
          _section('Usually starts', map.usuallyStartsBefore),
          _section('Often feels', _feelsLine()),
          _section('Gets lighter when', map.getsLighterWhen),
          _section('Gets heavier when', map.getsHeavierWhen),
          _section('Next check', map.nextCheck, emphasize: true),
          if (map.hasNextCheck && onUseCheck != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => onUseCheck!(map.nextCheck!.trim()),
                child: const Text('Use this check'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _seenLine() {
    if (map.seenCount <= 0) return null;
    final times = map.seenCount == 1 ? '1 time' : '${map.seenCount} times';
    final last = map.lastSeenDate;
    if (last == null) return times;
    return '$times · last ${_dateLabel(last)}';
  }

  String? _feelsLine() {
    final feels = map.oftenFeelsLike;
    if (feels == null || feels.isEmpty) return null;
    return feels == 'different' ? 'different each time' : feels;
  }

  Widget _section(String label, String? value, {bool emphasize = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: VoiceMemoryTypography.bodyStyle(color: AppColors.textPrimary)
                .copyWith(
                  fontSize: emphasize ? 16 : 15,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
