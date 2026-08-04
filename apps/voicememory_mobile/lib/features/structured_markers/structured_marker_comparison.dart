import '../explainable_conclusion/change_dimensions.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';
import 'structured_markers.dart';

/// Folds the optional ten-second check into dimension comparison as additional
/// structured evidence.
///
/// The saved words are authoritative. A marker may only supply a dimension the
/// two moments' own words cannot compare — that is, a dimension neither moment
/// mentions. Where the words speak, the words decide, so a marker can never
/// contradict, soften or reverse what the reader actually said.
abstract final class StructuredMarkerComparison {
  static ChangeDimensions compare({
    required String before,
    required String after,
    StructuredMarkers? beforeMarkers,
    StructuredMarkers? afterMarkers,
  }) {
    final fromWords = ChangeDimensionReader.compare(
      before: before,
      after: after,
    );
    final beforeMarkerObservations = observe(beforeMarkers);
    final afterMarkerObservations = observe(afterMarkers);
    if (beforeMarkerObservations.isEmpty || afterMarkerObservations.isEmpty) {
      return fromWords;
    }

    // Any dimension the words touch on either side is settled by the words.
    final spokenFor = <ChangeDimension>{
      for (final movement in fromWords.movements) movement.dimension,
      ...ChangeDimensionReader.read(before).keys,
      ...ChangeDimensionReader.read(after).keys,
    };

    final movements = <DimensionMovement>[...fromWords.movements];
    for (final dimension in ChangeDimension.values) {
      if (spokenFor.contains(dimension)) continue;
      final earlier = beforeMarkerObservations[dimension];
      final later = afterMarkerObservations[dimension];
      if (earlier == null || later == null) continue;
      movements.add(
        DimensionMovement(
          dimension: dimension,
          before: earlier,
          after: later,
          direction: _direction(earlier, later),
        ),
      );
    }
    movements.sort(
      (a, b) => ChangeDimension.values
          .indexOf(a.dimension)
          .compareTo(ChangeDimension.values.indexOf(b.dimension)),
    );
    return ChangeDimensions(
      sharedSubjectMarkers: fromWords.sharedSubjectMarkers,
      movements: List.unmodifiable(movements),
    );
  }

  /// Compares the earliest and latest supporting moments of [conclusion],
  /// including any markers those moments carry.
  ///
  /// Returns an empty comparison for a single-moment observation: one moment is
  /// not a comparison, and markers do not make it one.
  static ChangeDimensions forConclusion(
    ValidatedExplainableConclusion conclusion, {
    Map<String, StructuredMarkers> markers = const {},
  }) {
    final supporting = conclusion.value.evidence
        .where((citation) => citation.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    if (supporting.map((citation) => citation.entryId).toSet().length < 2) {
      return const ChangeDimensions.empty();
    }
    final dated =
        supporting
            .where((citation) => citation.sourceCapturedAt != null)
            .toList()
          ..sort((a, b) => a.sourceCapturedAt!.compareTo(b.sourceCapturedAt!));
    final ordered = dated.length < 2 ? supporting : dated;
    final earlier = ordered.first;
    final later = ordered.last;
    if (earlier.entryId == later.entryId) return const ChangeDimensions.empty();
    return compare(
      before: earlier.quote,
      after: later.quote,
      beforeMarkers: markers[earlier.entryId],
      afterMarkers: markers[later.entryId],
    );
  }

  /// The dimensions [markers] can speak to, in the same shape the word reader
  /// produces so both sources compare identically.
  ///
  /// "Other" is deliberately unmapped: it records that the reader answered
  /// without claiming what the answer was.
  static Map<ChangeDimension, DimensionObservation> observe(
    StructuredMarkers? markers,
  ) {
    if (markers == null || markers.isEmpty) return const {};
    final observations = <ChangeDimension, DimensionObservation>{};
    final strength = markers.strength;
    if (strength != null) {
      observations[ChangeDimension.emotionalIntensity] = DimensionObservation(
        dimension: ChangeDimension.emotionalIntensity,
        markers: Set.unmodifiable({strength.name.toLowerCase()}),
        ordinal: switch (strength) {
          MarkerStrength.low => 0,
          MarkerStrength.medium => 1,
          MarkerStrength.high => 2,
        },
      );
    }
    final action = markers.action;
    final actionMarker = switch (action) {
      MarkerAction.avoided => 'avoided',
      MarkerAction.continued => 'continued',
      MarkerAction.stopped => 'stopped',
      MarkerAction.askedForHelp => 'asked for help',
      MarkerAction.other || null => null,
    };
    if (actionMarker != null) {
      observations[ChangeDimension.behaviouralResponse] = DimensionObservation(
        dimension: ChangeDimension.behaviouralResponse,
        markers: Set.unmodifiable({actionMarker}),
      );
    }
    final resolution = markers.resolution;
    if (resolution != null) {
      observations[ChangeDimension.outcome] = DimensionObservation(
        dimension: ChangeDimension.outcome,
        markers: Set.unmodifiable({
          switch (resolution) {
            MarkerResolution.unresolved => 'unresolved',
            MarkerResolution.partlyResolved => 'partly resolved',
            MarkerResolution.resolved => 'resolved',
          },
        }),
        ordinal: switch (resolution) {
          MarkerResolution.unresolved => 0,
          MarkerResolution.partlyResolved => 1,
          MarkerResolution.resolved => 2,
        },
      );
    }
    return Map.unmodifiable(observations);
  }

  static DimensionDirection _direction(
    DimensionObservation before,
    DimensionObservation after,
  ) {
    final earlier = before.ordinal;
    final later = after.ordinal;
    if (earlier != null && later != null && earlier != later) {
      return later > earlier
          ? DimensionDirection.increased
          : DimensionDirection.decreased;
    }
    if (before.markers.intersection(after.markers).isNotEmpty) {
      return DimensionDirection.unchanged;
    }
    return earlier != null && later != null && earlier == later
        ? DimensionDirection.unchanged
        : DimensionDirection.replaced;
  }
}
