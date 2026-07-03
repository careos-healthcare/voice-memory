import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/proof_surface_why_appeared_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Collapsed-by-default one-line explainability disclosure for proof cards.
class ProofSurfaceWhyAppearedDisclosure extends StatefulWidget {
  const ProofSurfaceWhyAppearedDisclosure({
    super.key,
    required this.body,
    required this.surfaceKey,
  });

  final String body;
  final String surfaceKey;

  @override
  State<ProofSurfaceWhyAppearedDisclosure> createState() =>
      _ProofSurfaceWhyAppearedDisclosureState();
}

class _ProofSurfaceWhyAppearedDisclosureState
    extends State<ProofSurfaceWhyAppearedDisclosure> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.body.trim().isEmpty) return const SizedBox.shrink();

    final helperStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
      height: 1.4,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.45,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('proof_surface_why_appeared_link_${widget.surfaceKey}'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              ProofSurfaceWhyAppearedCopy.linkLabel,
              style: helperStyle.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textSecondary.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              ProofSurfaceWhyAppearedCopy.line(widget.body),
              key: Key('proof_surface_why_appeared_body_${widget.surfaceKey}'),
              style: bodyStyle,
            ),
          ),
      ],
    );
  }
}
