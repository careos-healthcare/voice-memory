import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_analytics.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/pro/pro_evidence_value_sheet.dart';
import 'package:flutter/material.dart';

/// Compact Pro evidence value bridge — opens Free vs Pro sheet.
class ProEvidenceValueCard extends StatefulWidget {
  const ProEvidenceValueCard({
    required this.surface, required this.entryCount, required this.onSeePro, required this.onDismiss, super.key,
    this.compact = false,
  });

  final ProEvidenceValueSurface surface;
  final int entryCount;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  State<ProEvidenceValueCard> createState() => _ProEvidenceValueCardState();
}

class _ProEvidenceValueCardState extends State<ProEvidenceValueCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    unawaited(BetaFeedbackIntelligenceStore.markProEvidenceBridgeSeen());
    ProEvidenceValueAnalytics.seen(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
    );
  }

  Future<void> _openSheet() async {
    ProEvidenceValueAnalytics.ctaTapped(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      actionType: 'open_sheet',
    );
    await ProEvidenceValueSheet.show(
      context,
      surface: widget.surface,
      entryCount: widget.entryCount,
      onSeePro: widget.onSeePro,
    );
  }

  void _handleDismiss() {
    ProEvidenceValueAnalytics.dismissed(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final display = ProEvidenceValueEngine.buildDisplay();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: Key(
        widget.compact
            ? 'pro_evidence_value_card_compact'
            : 'pro_evidence_value_card',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            display.title,
            key: const Key('pro_evidence_value_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.body,
            key: const Key('pro_evidence_value_body'),
            style: bodyStyle,
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              display.chatGptDifferentiationLine,
              key: const Key('pro_evidence_value_chatgpt_line'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_evidence_value_dismiss'),
                  onPressed: _handleDismiss,
                  child: Text(display.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_evidence_value_cta'),
                  onPressed: _openSheet,
                  child: Text(display.cta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}