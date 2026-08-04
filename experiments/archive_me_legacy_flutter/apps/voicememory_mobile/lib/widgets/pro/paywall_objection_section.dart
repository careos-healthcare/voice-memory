import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/paywall_objection_handling/paywall_objection_analytics.dart';
import '../../features/paywall_objection_handling/paywall_objection_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_colors.dart';

/// Expandable objection answers on the paywall — no purchase logic.
class PaywallObjectionSection extends StatefulWidget {
  const PaywallObjectionSection({super.key, required this.result});

  final PaywallObjectionSectionResult result;

  @override
  State<PaywallObjectionSection> createState() =>
      _PaywallObjectionSectionState();
}

class _PaywallObjectionSectionState extends State<PaywallObjectionSection> {
  var _trackedSeen = false;
  final _expandedTracked = <PaywallObjectionId>{};

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    _trackedSeen = true;
    PaywallObjectionAnalytics.sectionSeen(
      source: widget.result.source,
      surface: widget.result.surface,
    );
  }

  void _trackExpanded(PaywallObjectionId id) {
    if (_expandedTracked.contains(id)) return;
    _expandedTracked.add(id);
    PaywallObjectionAnalytics.expanded(
      source: widget.result.source,
      surface: widget.result.surface,
      objectionId: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow || widget.result.rows.isEmpty) {
      return const SizedBox.shrink(
        key: Key('paywall_objection_section_hidden'),
      );
    }

    _trackSeenOnce();

    final questionStyle = ArchiveMobileTypography.listTitle(
      context,
    ).copyWith(fontSize: 15);
    final answerStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Material(
      key: const Key('paywall_objection_section'),
      color: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        side: const BorderSide(color: VoiceMemoryColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.result.title,
              key: const Key('paywall_objection_section_title'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final row in widget.result.rows)
              Material(
                color: Colors.transparent,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: Key('paywall_objection_row_${row.id.name}'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(
                      row.question,
                      key: Key('paywall_objection_question_${row.id.name}'),
                      style: questionStyle,
                    ),
                    onExpansionChanged: (expanded) {
                      if (expanded) _trackExpanded(row.id);
                    },
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          row.answer,
                          key: Key('paywall_objection_answer_${row.id.name}'),
                          style: answerStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
