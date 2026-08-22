import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// "Not related" — rejects one suggested connection for this session.
///
/// Tapping suppresses only this card type for the current session and
/// swaps in a short thanks line. Nothing is deleted, archive history is
/// not rewritten, and memory stays on everywhere else.
class NotRelatedAction extends StatefulWidget {
  const NotRelatedAction({required this.cardType, super.key, this.onMarked});

  final MemoryCardType cardType;

  /// Lets the host screen rebuild immediately if it wants to collapse the
  /// card right away; the session store covers every later build.
  final VoidCallback? onMarked;

  @override
  State<NotRelatedAction> createState() => _NotRelatedActionState();
}

class _NotRelatedActionState extends State<NotRelatedAction> {
  bool _markedNow = false;

  void _mark() {
    MemoryControlStore.markNotRelated(widget.cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryMarkedNotRelated,
      cardType: widget.cardType.id,
    );
    setState(() => _markedNow = true);
    widget.onMarked?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_markedNow || MemoryControlStore.isSuppressed(widget.cardType)) {
      return Padding(
        key: Key('not_related_thanks_${widget.cardType.id}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          MemoryControlCopy.notRelatedThanks,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return TextButton(
      key: Key('not_related_action_${widget.cardType.id}'),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppColors.textSecondary,
      ),
      onPressed: _mark,
      child: Text(
        MemoryControlCopy.notRelatedLabel,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}