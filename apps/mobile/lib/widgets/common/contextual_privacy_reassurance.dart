import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/contextual_privacy/contextual_privacy_analytics.dart';
import 'package:archiveme_mobile/features/contextual_privacy/contextual_privacy_controls_sheet.dart';
import 'package:archiveme_mobile/features/contextual_privacy/contextual_privacy_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Quiet trust line on emotionally strong archive surfaces.
class ContextualPrivacyReassurance extends StatefulWidget {
  const ContextualPrivacyReassurance({
    required this.source, required this.entryCount, super.key,
    this.compact = true,
    this.onDeleteMoment,
    this.onRemoveFromPattern,
  });

  final String source;
  final int entryCount;
  final bool compact;
  final Future<void> Function()? onDeleteMoment;
  final Future<void> Function()? onRemoveFromPattern;

  @override
  State<ContextualPrivacyReassurance> createState() =>
      _ContextualPrivacyReassuranceState();
}

class _ContextualPrivacyReassuranceState
    extends State<ContextualPrivacyReassurance> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ContextualPrivacyAnalytics.reassuranceSeen(
      source: widget.source,
      entryCount: widget.entryCount,
    );
  }

  void _openControls() {
    unawaited(ContextualPrivacyControlsSheet.show(
      context,
      source: widget.source,
      onDeleteMoment: widget.onDeleteMoment,
      onRemoveFromPattern: widget.onRemoveFromPattern,
    ));
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final line = widget.compact
        ? ContextualPrivacyCopy.compactLine
        : ContextualPrivacyCopy.fullLine;
    final textStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.4);

    return Column(
      key: const Key('contextual_privacy_reassurance'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line,
          key: Key(
            widget.compact
                ? 'contextual_privacy_compact_line'
                : 'contextual_privacy_full_line',
          ),
          style: textStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          key: const Key('contextual_privacy_your_controls_link'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: _openControls,
          child: Text(
            ContextualPrivacyCopy.yourControlsLink,
            style: textStyle.copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}