import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/low_effort_check_in_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Small one-tap fallback under One Small Recording: when a full recording
/// feels like too much, one tap still adds something real to the archive.
/// Secondary by design — quiet styling, four options, one confirmation,
/// nothing else. Never blocks or replaces recording.
class LowEffortCheckInCard extends StatefulWidget {
  const LowEffortCheckInCard({required this.onSelect, super.key});

  /// Persists the chosen option; the confirmation only shows after this
  /// future completes, so "Saved" is never claimed before it is true.
  final Future<void> Function(LowEffortCheckInOption option) onSelect;

  @override
  State<LowEffortCheckInCard> createState() => _LowEffortCheckInCardState();
}

class _LowEffortCheckInCardState extends State<LowEffortCheckInCard> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _select(LowEffortCheckInOption option) async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    await widget.onSelect(option);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('low_effort_check_in_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F6F4),
      ),
      child: _saved
          ? Text(
              LowEffortCheckIn.confirmation,
              key: const Key('low_effort_confirmation'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LowEffortCheckIn.title,
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  LowEffortCheckIn.subtitle,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final option in LowEffortCheckInOption.values)
                      ActionChip(
                        key: Key('low_effort_option_${option.id}'),
                        label: Text(option.label),
                        onPressed: _saving ? null : () => _select(option),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}