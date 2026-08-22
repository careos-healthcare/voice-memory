import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Subtle, non-distracting trust indicators for archive and settings surfaces.
class TrustStatusFooter extends StatelessWidget {
  const TrustStatusFooter({super.key});

  static const Key footerKey = Key('trust_status_footer');
  static const Key encryptedKey = Key('trust_status_footer_encrypted');
  static const Key onDeviceKey = Key('trust_status_footer_on_device');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textMuted.withValues(alpha: 0.72),
      fontSize: 11,
      letterSpacing: 0.15,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );
    final iconColor = AppColors.textMuted.withValues(alpha: 0.55);
    final separatorColor = AppColors.textMuted.withValues(alpha: 0.4);

    return Semantics(
      container: true,
      label:
          '${TrustStatusFooterCopy.encryptedAtRest}. '
          '${TrustStatusFooterCopy.processedOnDevice}.',
      child: Padding(
        key: footerKey,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              _Indicator(
                key: encryptedKey,
                icon: Icons.lock_outline,
                label: TrustStatusFooterCopy.encryptedAtRest,
                semanticLabel: TrustStatusFooterCopy.encryptedSemanticLabel,
                iconColor: iconColor,
                labelStyle: labelStyle,
              ),
              Text(
                '·',
                style: labelStyle?.copyWith(color: separatorColor),
                semanticsLabel: '',
              ),
              _Indicator(
                key: onDeviceKey,
                icon: Icons.memory_outlined,
                label: TrustStatusFooterCopy.processedOnDevice,
                semanticLabel: TrustStatusFooterCopy.onDeviceSemanticLabel,
                iconColor: iconColor,
                labelStyle: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.iconColor,
    required this.labelStyle,
    super.key,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color iconColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
