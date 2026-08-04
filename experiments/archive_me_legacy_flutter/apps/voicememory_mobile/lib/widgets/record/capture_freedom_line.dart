import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/proof_specificity/proof_specificity_analytics.dart';
import '../../features/proof_specificity/proof_specificity_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Small capture guidance for early users — no CTA, no therapy claims.
class CaptureFreedomLine extends StatefulWidget {
  const CaptureFreedomLine({
    super.key,
    required this.source,
    required this.entryCount,
    this.compact = false,
  });

  const CaptureFreedomLine.test({
    super.key,
    required this.source,
    required this.entryCount,
    this.compact = false,
  });

  final String source;
  final int entryCount;
  final bool compact;

  @override
  State<CaptureFreedomLine> createState() => _CaptureFreedomLineState();
}

class _CaptureFreedomLineState extends State<CaptureFreedomLine> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ProofSpecificityAnalytics.captureFreedomSeen(
      source: widget.source,
      entryCount: widget.entryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final text = widget.compact
        ? ProofSpecificityCopy.captureFreedomLineCompact
        : ProofSpecificityCopy.captureFreedomLine;

    return Padding(
      key: const Key('capture_freedom_line'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        text,
        key: Key('capture_freedom_line_${widget.compact ? 'compact' : 'full'}'),
        style: ArchiveMobileTypography.explanationBody(
          context,
        ).copyWith(color: AppColors.textSecondary, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }
}
