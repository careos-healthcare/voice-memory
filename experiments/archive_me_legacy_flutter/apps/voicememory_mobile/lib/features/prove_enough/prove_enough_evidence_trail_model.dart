/// One saved moment in the prove_enough evidence trail — excerpt only.
class ProveEnoughEvidenceMoment {
  const ProveEnoughEvidenceMoment({
    required this.entryId,
    required this.createdAt,
    required this.excerpt,
  });

  final String entryId;
  final DateTime createdAt;
  final String excerpt;
}

/// Full prove_enough evidence trail assembled from real journal data.
class ProveEnoughEvidenceTrail {
  const ProveEnoughEvidenceTrail({
    required this.supportingMoments,
    required this.contradictionMoments,
    required this.restGuiltMoments,
    required this.choiceMoments,
    required this.triggerSummary,
    required this.whatChanged,
    this.latestMission,
  });

  static const freePreviewLimit = 3;

  static const screenTitle = 'Full evidence trail';
  static const screenSubtitle =
      'See what confirms, challenges, and changes the proving-enough loop.';

  static const confirmedSectionTitle = 'What confirmed the loop';
  static const challengedSectionTitle = 'What challenged the loop';
  static const restGuiltSectionTitle = 'Rest guilt';
  static const choiceSectionTitle = 'Choice vs pressure';
  static const triggerSectionTitle = 'Trigger map';
  static const changedSectionTitle = 'What changed';

  static const lockedTitle = 'Keep the full evidence trail';
  static const lockedBody =
      'Pro keeps tracking whether this loop fades, gets stronger, or changes.';
  static const lockedCta = 'See Pro';

  final List<ProveEnoughEvidenceMoment> supportingMoments;
  final List<ProveEnoughEvidenceMoment> contradictionMoments;
  final List<ProveEnoughEvidenceMoment> restGuiltMoments;
  final List<ProveEnoughEvidenceMoment> choiceMoments;
  final String triggerSummary;
  final String whatChanged;
  final String? latestMission;

  List<ProveEnoughEvidenceMoment> get previewMoments =>
      supportingMoments.take(freePreviewLimit).toList();

  bool get hasPreview => previewMoments.isNotEmpty;

  bool get hasExtendedContent =>
      supportingMoments.length > freePreviewLimit ||
      contradictionMoments.isNotEmpty ||
      restGuiltMoments.isNotEmpty ||
      choiceMoments.isNotEmpty ||
      triggerSummary.trim().isNotEmpty ||
      whatChanged.trim().isNotEmpty ||
      (latestMission?.trim().isNotEmpty ?? false);
}
