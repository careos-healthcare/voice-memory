import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Quiet encryption-at-rest baseline, sized to sit under the primary on-device
/// messaging rather than compete with it.
///
/// Deliberately static and deliberately *not* a status readout. It states the
/// storage design; `EncryptionStatusCard` reports whether the running build has
/// it available. Putting both on one screen only works when the static line is
/// scoped so it cannot contradict the live one — hence the wording in
/// [PrivacyCopyPolicy.encryptionBaselineDetail], which names the platforms the
/// database half depends on instead of asserting a state.
///
/// Type is one step below body copy and the icon is 12px on a muted colour, so
/// it reads as a footnote. It carries no live state, so it never needs to
/// rebuild.
class EncryptionBaselineBadge extends StatelessWidget {
  const EncryptionBaselineBadge({super.key});

  static const Key badgeKey = Key('encryption_baseline_badge');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = AppColors.textMuted.withValues(alpha: 0.78);
    final detailColor = AppColors.textMuted.withValues(alpha: 0.62);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${PrivacyCopyPolicy.encryptedAtRestScoped}. '
          '${PrivacyCopyPolicy.encryptionBaselineDetail}',
      child: Padding(
        key: badgeKey,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Nudge the glyph onto the first text line rather than the
                  // top of the box, which matters once the label wraps.
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 6),
                // Flexible, not fixed: at large text scales the label is wider
                // than a phone and has to wrap instead of overflowing.
                Flexible(
                  child: Text(
                    PrivacyCopyPolicy.encryptedAtRestScoped,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              PrivacyCopyPolicy.encryptionBaselineDetail,
              style: theme.textTheme.labelSmall?.copyWith(
                color: detailColor,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
