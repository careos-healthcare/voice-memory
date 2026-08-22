import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:flutter/foundation.dart';

/// One step in the sample archive guided tour.
class SampleArchiveTourStep {
  const SampleArchiveTourStep({required this.title, required this.body});

  final String title;
  final String body;
}

/// Session-only tour state for `/sample-archive` — never persisted.
abstract final class SampleArchiveTour {
  SampleArchiveTour._();

  static const steps = <SampleArchiveTourStep>[
    SampleArchiveTourStep(
      title: SampleArchiveCopy.tourStep1Title,
      body: SampleArchiveCopy.tourStep1Body,
    ),
    SampleArchiveTourStep(
      title: SampleArchiveCopy.tourStep2Title,
      body: SampleArchiveCopy.tourStep2Body,
    ),
    SampleArchiveTourStep(
      title: SampleArchiveCopy.tourStep3Title,
      body: SampleArchiveCopy.tourStep3Body,
    ),
    SampleArchiveTourStep(
      title: SampleArchiveCopy.tourStep4Title,
      body: SampleArchiveCopy.tourStep4Body,
    ),
    SampleArchiveTourStep(
      title: SampleArchiveCopy.tourStep5Title,
      body: SampleArchiveCopy.tourStep5Body,
    ),
  ];

  static var _dismissedForSession = false;
  static var _collapsedForSession = false;

  static bool get dismissedForSession => _dismissedForSession;

  static bool get collapsedForSession => _collapsedForSession;

  static bool get shouldShow => !_dismissedForSession;

  static void dismissForSession() {
    _dismissedForSession = true;
  }

  static void setCollapsedForSession(bool collapsed) {
    _collapsedForSession = collapsed;
  }

  @visibleForTesting
  static void resetForTest() {
    _dismissedForSession = false;
    _collapsedForSession = false;
  }
}