import 'dart:async';

import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_trail_button.dart'
    as verified_trail;
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Production control that opens verified source quotes only.
///
/// Distinct from [EvidenceTrailButton] in this file, which is the
/// layout-preview API and must never be wired to
/// `VerifiedSourceProofSheet`.
typedef VerifiedEvidenceTrailButton = verified_trail.EvidenceTrailButton;

/// One row in a preview evidence trail.
///
/// These are display rows only. They are not verified quotes and must
/// never be passed into `VerifiedSourceProofSheet` or `VerbatimEvidence`.
class EvidencePoint {
  const EvidencePoint({
    required this.label,
    required this.text,
    this.at,
  });

  /// Row kind. Preview samples use [sampleLabel], never
  /// "Transcript excerpt".
  final String label;

  /// Display text for the row.
  final String text;

  /// Optional journal date shown under the text.
  final DateTime? at;

  /// Honest label for mock rows so they cannot be read as stored quotes.
  static const String sampleLabel = 'Sample';

  /// Non-privacy sample journal lines for debug layout review.
  static final List<EvidencePoint> previewJournalSamples = [
    EvidencePoint(
      label: sampleLabel,
      text: 'I left the kitchen light on and made tea before sitting down.',
      at: DateTime(2026, 6, 12),
    ),
    EvidencePoint(
      label: sampleLabel,
      text: 'I walked around the block before I opened the laptop.',
      at: DateTime(2026, 7, 3),
    ),
  ];
}

/// Spacious Material 3 sheet that lists [EvidencePoint] rows.
///
/// Preview-only. Does not construct or display `VerbatimEvidence`.
class EvidenceTrailBottomSheet extends StatelessWidget {
  const EvidenceTrailBottomSheet({
    required this.title,
    required this.points,
    super.key,
  });

  /// Sheet heading. Mock usage must use [previewTitle].
  final String title;

  /// Rows to list. Callers that pass sample data must label them
  /// [EvidencePoint.sampleLabel].
  final List<EvidencePoint> points;

  static const Key sheetKey = Key('evidence_trail_preview_sheet');

  static const String defaultTitle = 'How we know this pattern';

  /// Title that makes mock data impossible to mistake for live proof.
  static const String previewTitle = 'How we know this pattern (preview)';

  static const String previewLead =
      'Sample journal lines for layout review. These are not stored quotes.';

  /// Opens this sheet. Never opens `VerifiedSourceProofSheet`.
  static Future<void> show(
    BuildContext context, {
    required List<EvidencePoint> points,
    String title = previewTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EvidenceTrailBottomSheet(
        title: title,
        points: points,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.36,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          key: sheetKey,
          color: AppColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: VoiceMemoryTypography.pageTitleStyle().copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                  children: [
                    Text(
                      previewLead,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textMuted,
                      ).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < points.length; i++)
                      Padding(
                        key: Key('evidence_trail_preview_point_$i'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _EvidencePointCard(point: points[i]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EvidencePointCard extends StatelessWidget {
  const _EvidencePointCard({required this.point});

  final EvidencePoint point;

  @override
  Widget build(BuildContext context) {
    final recorded = point.at;
    final recordedLabel = recorded == null
        ? null
        : formatUserFacingDate(recorded);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              point.label,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textMuted,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              point.text,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(height: 1.45),
            ),
            if (recordedLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                recordedLabel,
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small tappable chip that opens [EvidenceTrailBottomSheet].
///
/// This is the preview/layout API. It accepts [EvidencePoint] rows and
/// never constructs `VerbatimEvidence`. Production claim surfaces keep
/// using [VerifiedEvidenceTrailButton].
class EvidenceTrailButton extends StatelessWidget {
  const EvidenceTrailButton({
    required this.points,
    super.key,
    this.tooltip = 'Source Data',
    this.sheetTitle = EvidenceTrailBottomSheet.previewTitle,
    this.previewChrome = false,
  });

  final List<EvidencePoint> points;

  /// Tooltip / semantics for the chip.
  final String tooltip;

  /// Sheet heading. Defaults to the preview title so mock rows cannot
  /// appear under the live proof heading.
  final String sheetTitle;

  /// When true, the chip is dashed and labeled "Preview".
  final bool previewChrome;

  static const Key buttonKey = Key('shared_evidence_trail_button');

  static const Key previewButtonKey = Key('evidence_trail_preview_button');

  static const double minTapTarget = 48;

  void _open(BuildContext context) {
    unawaited(
      EvidenceTrailBottomSheet.show(
        context,
        points: points,
        title: sheetTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = previewChrome ? 'Preview' : tooltip;

    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          key: previewChrome ? previewButtonKey : buttonKey,
          color: previewChrome
              ? AppColors.warmSurface
              : AppColors.accentLight,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minTapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      previewChrome
                          ? Icons.science_outlined
                          : Icons.menu_book_outlined,
                      size: 18,
                      color: previewChrome
                          ? AppColors.warning
                          : AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: VoiceMemoryTypography.metadataStyle(
                        color: previewChrome
                            ? AppColors.warning
                            : AppColors.accentPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Debug-only chip that opens the preview sheet with sample journal lines.
///
/// Hidden when [kDebugMode] is false. Release builds do not show mock
/// quotes on insight cards.
class EvidenceTrailDebugPreview extends StatelessWidget {
  const EvidenceTrailDebugPreview({
    super.key,
    this.forceVisible,
  });

  /// Test hook. `null` follows [kDebugMode].
  final bool? forceVisible;

  static const Key bannerKey = Key('evidence_trail_debug_preview');

  static const String tooltip = 'Source preview';

  bool get _visible => forceVisible ?? kDebugMode;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return DecoratedBox(
      key: bannerKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: EvidenceTrailButton(
        points: EvidencePoint.previewJournalSamples,
        tooltip: tooltip,
        sheetTitle: EvidenceTrailBottomSheet.previewTitle,
        previewChrome: true,
      ),
    );
  }
}
