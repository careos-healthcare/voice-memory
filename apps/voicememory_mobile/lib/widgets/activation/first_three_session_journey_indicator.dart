import 'package:flutter/material.dart';

import '../../features/activation/first_three_session_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact three-step journey indicator — not gamified, just the product path.
class FirstThreeSessionJourneyIndicator extends StatelessWidget {
  const FirstThreeSessionJourneyIndicator({
    super.key,
    required this.activeStepIndex,
    this.compact = false,
  });

  /// 0 = start archive, 1 = notice repeats, 2 = watch changes.
  final int activeStepIndex;
  final bool compact;

  static const _labels = [
    FirstThreeSessionCopy.journeyStep1,
    FirstThreeSessionCopy.journeyStep2,
    FirstThreeSessionCopy.journeyStep3,
  ];

  @override
  Widget build(BuildContext context) {
    final active = activeStepIndex.clamp(0, 2);
    return Semantics(
      label: _labels[active],
      child: Row(
        key: const Key('first_three_session_journey_indicator'),
        children: List.generate(_labels.length, (index) {
          final isActive = index == active;
          final isPast = index < active;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : AppSpacing.xs / 2,
                right: index == _labels.length - 1 ? 0 : AppSpacing.xs / 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: compact ? 3 : 4,
                    decoration: BoxDecoration(
                      color: isActive || isPast
                          ? AppColors.accentPrimary
                          : AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
