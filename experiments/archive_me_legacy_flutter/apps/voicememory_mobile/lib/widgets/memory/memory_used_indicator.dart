import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_control_model.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';

/// Small "Memory used" / "Saved as new" label.
///
/// Shown only on record/insight surfaces where memory is actually
/// relevant: connected insight cards say "Memory used", a fresh save says
/// "Saved as new". Never rendered on settings, auth, app lock, paywall,
/// referral, or security screens.
class MemoryUsedIndicator extends StatelessWidget {
  const MemoryUsedIndicator({
    super.key,
    required this.connected,
    required this.source,
  });

  /// Whether this surface used archive memory (true) or is a fresh,
  /// unconnected save (false).
  final bool connected;

  /// Stable surface id for analytics de-dupe only (e.g. 'thread_return').
  final String source;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryUsedIndicatorSeen,
      connectionMode: connected ? 'connected' : 'fresh',
      source: source,
      oncePerSession: true,
    );
    return Container(
      key: Key(connected ? 'memory_used_indicator' : 'saved_as_new_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.link_outlined : Icons.fiber_new_outlined,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            connected
                ? MemoryControlCopy.memoryUsedLabel
                : MemoryControlCopy.savedAsNewLabel,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
