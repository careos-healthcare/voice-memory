import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/citation_badge.dart';
import 'package:archiveme_mobile/features/archive_theory/views/evolving_view_card.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_card.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_page_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

typedef TheoryXRayCallback = void Function(TrackedTheory theory);
typedef TheoryConnectionMapCallback = void Function(TrackedTheory theory);

class TheoriesView extends StatelessWidget {
  const TheoriesView({
    required this.report,
    required this.evolvingSnapshot,
    required this.reflectionCount,
    super.key,
    this.onCitationTap,
    this.onConnectionMapTap,
    this.onXRayTap,
    this.showXRay = false,
  });

  final TheoryTrackerReport report;
  final EvolvingViewSnapshot evolvingSnapshot;
  final int reflectionCount;
  final CitationPlaybackCallback? onCitationTap;
  final TheoryConnectionMapCallback? onConnectionMapTap;
  final TheoryXRayCallback? onXRayTap;
  final bool showXRay;

  @override
  Widget build(BuildContext context) {
    if (report.all.isEmpty) {
      return Container(
        key: const Key('theories_view_empty'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              TheoryPageCopy.emptyTitle,
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              TheoryPageCopy.emptyBody,
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('theories_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvolvingViewCard(
          snapshot: evolvingSnapshot,
          reflectionCount: reflectionCount,
        ),
        const SizedBox(height: AppSpacing.lg),
        _section(context, TheoryPageCopy.strengtheningTitle, report.strengthening),
        _section(context, TheoryPageCopy.weakeningTitle, report.weakening),
        _section(context, TheoryPageCopy.activeTitle, report.active),
        _section(context, TheoryPageCopy.resolvedTitle, report.resolved),
        _section(context, TheoryPageCopy.retiredTitle, report.retired),
      ],
    );
  }

  void _openXRay(TrackedTheory theory) {
    onXRayTap?.call(theory);
  }

  void _openConnectionMap(TrackedTheory theory) {
    onConnectionMapTap?.call(theory);
  }

  Widget _section(
    BuildContext context,
    String title,
    List<TrackedTheory> theories,
  ) {
    if (theories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          ...theories.map((theory) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TheoryCard(
                  theory: theory,
                  onCitationTap: onCitationTap,
                  onConnectionMapTap: onConnectionMapTap == null
                      ? null
                      : () => _openConnectionMap(theory),
                  showXRay: showXRay,
                  onXRayTap: theory.inspection == null
                      ? null
                      : () => _openXRay(theory),
                ),
              )),
        ],
      ),
    );
  }
}