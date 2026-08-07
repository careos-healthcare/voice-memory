/// Surfaces where beta feedback capture can appear.
enum BetaFeedbackCaptureSurface {
  recordReady,
  recordPostSave,
  patterns,
  paywall,
}

/// Revenue breakpoint moments — stable analytics ids.
enum BetaFeedbackCaptureMoment {
  afterFirstSave,
  afterThirdSave,
  afterTimelineProof,
  afterProPreview,
  afterPaywallSeenNoCta,
  afterPaywallCtaNoPurchase,
}

extension BetaFeedbackCaptureMomentStorage on BetaFeedbackCaptureMoment {
  String get storageValue => switch (this) {
    BetaFeedbackCaptureMoment.afterFirstSave => 'after_first_save',
    BetaFeedbackCaptureMoment.afterThirdSave => 'after_third_save',
    BetaFeedbackCaptureMoment.afterTimelineProof => 'after_timeline_proof',
    BetaFeedbackCaptureMoment.afterProPreview => 'after_pro_preview',
    BetaFeedbackCaptureMoment.afterPaywallSeenNoCta =>
      'after_paywall_seen_no_cta',
    BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase =>
      'after_paywall_cta_no_purchase',
  };

  String get analyticsValue => storageValue;
}

extension BetaFeedbackCaptureSurfaceStorage on BetaFeedbackCaptureSurface {
  String get analyticsValue => switch (this) {
    BetaFeedbackCaptureSurface.recordReady => 'record_ready',
    BetaFeedbackCaptureSurface.recordPostSave => 'record_post_save',
    BetaFeedbackCaptureSurface.patterns => 'patterns',
    BetaFeedbackCaptureSurface.paywall => 'paywall',
  };
}

/// Visibility inputs for one surface audit.
class BetaFeedbackCaptureContext {
  const BetaFeedbackCaptureContext({
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.betaMissionEnabled,
    required this.isReady,
    required this.isRecording,
    required this.isPostSave,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.hasUsefulProof,
    required this.hasPaywallSeen,
    required this.hasPurchaseCtaTapped,
    required this.isPro,
    required this.timelineProofVisible,
    required this.proPreviewVisible,
    required this.existingProofFeedbackVisible,
    required this.coreCaptureCtaVisible,
    required this.paywallNoCtaRequested,
    required this.paywallPurchaseAttempted,
  });

  final BetaFeedbackCaptureSurface surface;
  final String source;
  final int entryCount;
  final bool betaMissionEnabled;
  final bool isReady;
  final bool isRecording;
  final bool isPostSave;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool hasUsefulProof;
  final bool hasPaywallSeen;
  final bool hasPurchaseCtaTapped;
  final bool isPro;
  final bool timelineProofVisible;
  final bool proPreviewVisible;
  final bool existingProofFeedbackVisible;
  final bool coreCaptureCtaVisible;
  final bool paywallNoCtaRequested;
  final bool paywallPurchaseAttempted;
}

/// Resolved card payload for one moment.
class BetaFeedbackCaptureResult {
  const BetaFeedbackCaptureResult({
    required this.shouldShow,
    required this.moment,
    required this.title,
    required this.options,
    required this.followUpPlaceholder,
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.hasPaywallSeen,
    required this.hasPurchaseCtaTapped,
    required this.unresolvedRevenueQuestion,
  });

  static const hidden = BetaFeedbackCaptureResult(
    shouldShow: false,
    moment: BetaFeedbackCaptureMoment.afterFirstSave,
    title: '',
    options: [],
    followUpPlaceholder: null,
    source: '',
    surface: BetaFeedbackCaptureSurface.recordReady,
    entryCount: 0,
    hasUsefulProof: false,
    hasPaywallSeen: false,
    hasPurchaseCtaTapped: false,
    unresolvedRevenueQuestion: '',
  );

  final bool shouldShow;
  final BetaFeedbackCaptureMoment moment;
  final String title;
  final List<BetaFeedbackCaptureOption> options;
  final String? followUpPlaceholder;
  final String source;
  final BetaFeedbackCaptureSurface surface;
  final int entryCount;
  final bool hasUsefulProof;
  final bool hasPaywallSeen;
  final bool hasPurchaseCtaTapped;
  final String unresolvedRevenueQuestion;
}

class BetaFeedbackCaptureOption {
  const BetaFeedbackCaptureOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Local-only answer record — metadata only in analytics.
class BetaFeedbackCaptureRecord {
  const BetaFeedbackCaptureRecord({
    this.moment,
    this.answerId,
    this.dateKey,
    this.source,
    this.entryCount,
    this.freeTextLocal,
    this.answeredAt,
    this.dismissed = false,
  });

  static const empty = BetaFeedbackCaptureRecord();

  final BetaFeedbackCaptureMoment? moment;
  final String? answerId;
  final String? dateKey;
  final String? source;
  final int? entryCount;
  final String? freeTextLocal;
  final DateTime? answeredAt;
  final bool dismissed;

  bool get answered => answerId != null && answerId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (moment != null) 'moment': moment!.storageValue,
    if (answerId != null) 'answerId': answerId,
    if (dateKey != null) 'dateKey': dateKey,
    if (source != null) 'source': source,
    if (entryCount != null) 'entryCount': entryCount,
    if (freeTextLocal != null && freeTextLocal!.isNotEmpty)
      'freeTextLocal': freeTextLocal,
    if (answeredAt != null) 'answeredAt': answeredAt!.toUtc().toIso8601String(),
    if (dismissed) 'dismissed': true,
  };

  factory BetaFeedbackCaptureRecord.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return BetaFeedbackCaptureRecord(
      moment: _momentFromRaw(json['moment'] as String?),
      answerId: json['answerId'] is String ? json['answerId'] as String : null,
      dateKey: json['dateKey'] is String ? json['dateKey'] as String : null,
      source: json['source'] is String ? json['source'] as String : null,
      entryCount: json['entryCount'] is int ? json['entryCount'] as int : null,
      freeTextLocal: json['freeTextLocal'] is String
          ? json['freeTextLocal'] as String
          : null,
      answeredAt: _timestampFromRaw(json['answeredAt'] as String?),
      dismissed: json['dismissed'] == true,
    );
  }

  static BetaFeedbackCaptureMoment? _momentFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return BetaFeedbackCaptureMoment.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => BetaFeedbackCaptureMoment.afterFirstSave,
    );
  }

  static DateTime? _timestampFromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
