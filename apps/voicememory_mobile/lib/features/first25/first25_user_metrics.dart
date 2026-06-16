import '../../services/product_analytics.dart';
import 'first25_recording_retention.dart';

/// First 25 users — product funnel events (Firebase Analytics).
abstract class First25UserMetrics {
  First25UserMetrics._();

  // Activation
  static const String recordingCreated = 'recording_created';
  static const String recordingDay1 = 'recording_day1';
  static const String recordingDay3 = 'recording_day3';
  static const String recordingDay7 = 'recording_day7';

  // Archive engagement
  static const String archiveOpened = 'archive_opened';
  static const String evidenceOpened = 'evidence_opened';
  static const String theoryOpened = 'theory_opened';
  static const String deepDiveOpened = 'deep_dive_opened';

  // Conversion
  static const String paywallSeen = 'paywall_seen';
  static const String paywallDismissed = 'paywall_dismissed';
  static const String paywallStarted = 'paywall_started';
  static const String paywallPurchased = 'paywall_purchased';

  // Sharing
  static const String shareCardOpened = 'share_card_opened';
  static const String shareCardShared = 'share_card_shared';

  static Future<void> trackRecordingCreated({
    required String entryId,
    required String source,
  }) {
    return ProductAnalytics.trackStrings(recordingCreated, {
      'entry_id': entryId,
      'source': source,
    });
  }

  static Future<void> trackRecordingDay({
    required int day,
    required String entryId,
  }) {
    final event = switch (day) {
      1 => recordingDay1,
      3 => recordingDay3,
      7 => recordingDay7,
      _ => null,
    };
    if (event == null) return Future.value();
    return ProductAnalytics.trackStrings(event, {
      'entry_id': entryId,
      'cohort_day': '$day',
    });
  }

  static Future<void> trackArchiveOpened({required String surface}) {
    return ProductAnalytics.trackStrings(archiveOpened, {'surface': surface});
  }

  static Future<void> trackEvidenceOpened({required String surface}) {
    return ProductAnalytics.trackStrings(evidenceOpened, {'surface': surface});
  }

  static Future<void> trackTheoryOpened({required String surface}) {
    return ProductAnalytics.trackStrings(theoryOpened, {'surface': surface});
  }

  static Future<void> trackDeepDiveOpened({required String surface}) {
    return ProductAnalytics.trackStrings(deepDiveOpened, {'surface': surface});
  }

  static Future<void> trackPaywallSeen({
    required String surface,
    String? variant,
  }) {
    return ProductAnalytics.trackStrings(paywallSeen, {
      'surface': surface,
      if (variant != null) 'variant': variant,
    });
  }

  static Future<void> trackPaywallDismissed({required String surface}) {
    return ProductAnalytics.trackStrings(paywallDismissed, {
      'surface': surface,
    });
  }

  static Future<void> trackPaywallStarted({
    required String surface,
    String? period,
  }) {
    return ProductAnalytics.trackStrings(paywallStarted, {
      'surface': surface,
      if (period != null) 'period': period,
    });
  }

  static Future<void> trackPaywallPurchased({
    required String surface,
    String? period,
  }) {
    return ProductAnalytics.trackStrings(paywallPurchased, {
      'surface': surface,
      if (period != null) 'period': period,
    });
  }

  static Future<void> trackShareCardOpened({
    required String surface,
    required String cardType,
  }) {
    return ProductAnalytics.trackStrings(shareCardOpened, {
      'surface': surface,
      'card_type': cardType,
    });
  }

  static Future<void> trackShareCardShared({
    required String surface,
    required String cardType,
    required String exportMethod,
  }) {
    return ProductAnalytics.trackStrings(shareCardShared, {
      'surface': surface,
      'card_type': cardType,
      'export_method': exportMethod,
    });
  }

  /// Eligible reflection saved — activation + D1/D3/D7 retention milestones.
  static Future<void> onEligibleRecordingSaved({
    required String entryId,
    required DateTime createdAt,
    required String source,
  }) async {
    await trackRecordingCreated(entryId: entryId, source: source);
    final days = await First25RecordingRetention.recordEligibleRecording(
      createdAt: createdAt,
    );
    for (final day in days) {
      await trackRecordingDay(day: day, entryId: entryId);
    }
  }
}
