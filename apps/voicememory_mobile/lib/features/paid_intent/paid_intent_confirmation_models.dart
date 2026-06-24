/// Fixed paid intent response ids — no free text.
abstract final class PaidIntentConfirmationResponseIds {
  PaidIntentConfirmationResponseIds._();

  static const yes999 = 'yes_999';
  static const maybe = 'maybe';
  static const notYet = 'not_yet';
  static const no = 'no';

  static const all = [yes999, maybe, notYet, no];
}

/// Local record status — answered or skipped only.
enum PaidIntentConfirmationStatus {
  answered,
  skipped,
}

/// Value signals captured at response time — counts and flags only.
class PaidIntentValueSignalsAtResponse {
  const PaidIntentValueSignalsAtResponse({
    required this.capacityMomentCount,
    required this.fitResponse,
    required this.dailyChangeAvailable,
    required this.weeklyReviewAvailable,
    required this.boundaryResponseSelected,
  });

  final int capacityMomentCount;
  final String fitResponse;
  final bool dailyChangeAvailable;
  final bool weeklyReviewAvailable;
  final bool boundaryResponseSelected;

  Map<String, dynamic> toJson() => {
        'capacityMomentCount': capacityMomentCount,
        'fitResponse': fitResponse,
        'dailyChangeAvailable': dailyChangeAvailable,
        'weeklyReviewAvailable': weeklyReviewAvailable,
        'boundaryResponseSelected': boundaryResponseSelected,
      };

  static PaidIntentValueSignalsAtResponse? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final fit = json['fitResponse'];
    if (fit is! String || fit.isEmpty) return null;
    return PaidIntentValueSignalsAtResponse(
      capacityMomentCount: json['capacityMomentCount'] as int? ?? 0,
      fitResponse: fit,
      dailyChangeAvailable: json['dailyChangeAvailable'] as bool? ?? false,
      weeklyReviewAvailable: json['weeklyReviewAvailable'] as bool? ?? false,
      boundaryResponseSelected:
          json['boundaryResponseSelected'] as bool? ?? false,
    );
  }
}

/// Local paid intent confirmation record — metadata only.
class PaidIntentConfirmationRecord {
  const PaidIntentConfirmationRecord({
    this.responseId = '',
    this.source = PaidIntentConfirmationSource.capacityBetaValueSignal,
    this.status = PaidIntentConfirmationStatus.answered,
    this.valueSignalsAtResponse,
    this.createdAt,
    this.updatedAt,
  });

  final String responseId;
  final String source;
  final PaidIntentConfirmationStatus status;
  final PaidIntentValueSignalsAtResponse? valueSignalsAtResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComplete =>
      status == PaidIntentConfirmationStatus.skipped ||
      (status == PaidIntentConfirmationStatus.answered &&
          responseId.isNotEmpty);

  bool get isAnswered =>
      status == PaidIntentConfirmationStatus.answered && responseId.isNotEmpty;

  bool get isSkipped => status == PaidIntentConfirmationStatus.skipped;

  bool get isStrongWtp =>
      responseId == PaidIntentConfirmationResponseIds.yes999;

  bool get isSoftWtp => responseId == PaidIntentConfirmationResponseIds.maybe;

  bool get countsAsPaidReady => isStrongWtp || isSoftWtp;

  PaidIntentConfirmationRecord copyWith({
    String? responseId,
    String? source,
    PaidIntentConfirmationStatus? status,
    PaidIntentValueSignalsAtResponse? valueSignalsAtResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaidIntentConfirmationRecord(
      responseId: responseId ?? this.responseId,
      source: source ?? this.source,
      status: status ?? this.status,
      valueSignalsAtResponse:
          valueSignalsAtResponse ?? this.valueSignalsAtResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (responseId.isNotEmpty) 'responseId': responseId,
        'source': source,
        'status': status.name,
        if (valueSignalsAtResponse != null)
          'valueSignalsAtResponse': valueSignalsAtResponse!.toJson(),
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  static PaidIntentConfirmationRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final statusRaw = json['status'];
    PaidIntentConfirmationStatus status =
        PaidIntentConfirmationStatus.answered;
    if (statusRaw is String) {
      for (final value in PaidIntentConfirmationStatus.values) {
        if (value.name == statusRaw) {
          status = value;
          break;
        }
      }
    }
    DateTime? createdAt;
    DateTime? updatedAt;
    final createdRaw = json['createdAt'];
    if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
    final updatedRaw = json['updatedAt'];
    if (updatedRaw is String) updatedAt = DateTime.tryParse(updatedRaw);
    final signalsRaw = json['valueSignalsAtResponse'];
    return PaidIntentConfirmationRecord(
      responseId: json['responseId'] as String? ?? '',
      source: json['source'] as String? ??
          PaidIntentConfirmationSource.capacityBetaValueSignal,
      status: status,
      valueSignalsAtResponse: signalsRaw is Map<String, dynamic>
          ? PaidIntentValueSignalsAtResponse.fromJson(signalsRaw)
          : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

abstract final class PaidIntentConfirmationSource {
  PaidIntentConfirmationSource._();

  static const capacityBetaValueSignal = 'capacity_beta_value_signal';
}

/// Engine input — local counts and flags only.
class PaidIntentConfirmationInput {
  const PaidIntentConfirmationInput({
    required this.sampleMode,
    required this.screenshotMode,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.realSavedMomentCount,
    required this.fitIsPositive,
    required this.fitResponseLabel,
    required this.dailyChangeShown,
    required this.weeklyReviewAvailable,
    required this.returnedByDay7,
    required this.boundaryResponseSelected,
    required this.record,
  });

  final bool sampleMode;
  final bool screenshotMode;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int realSavedMomentCount;
  final bool fitIsPositive;
  final String fitResponseLabel;
  final bool dailyChangeShown;
  final bool weeklyReviewAvailable;
  final bool returnedByDay7;
  final bool boundaryResponseSelected;
  final PaidIntentConfirmationRecord? record;

  bool get hasReturnSignal => weeklyReviewAvailable || returnedByDay7;
}

/// Engine result — card visibility and answered summary.
class PaidIntentConfirmationResult {
  const PaidIntentConfirmationResult({
    required this.showCard,
    required this.showOnWeeklyReview,
    required this.showOnSupportLink,
    required this.title,
    required this.body,
    required this.question,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.answeredSummaryLine,
    required this.responseOptions,
  });

  static const hidden = PaidIntentConfirmationResult(
    showCard: false,
    showOnWeeklyReview: false,
    showOnSupportLink: false,
    title: '',
    body: '',
    question: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    answeredSummaryLine: '',
    responseOptions: [],
  );

  final bool showCard;
  final bool showOnWeeklyReview;
  final bool showOnSupportLink;
  final String title;
  final String body;
  final String question;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String answeredSummaryLine;
  final List<String> responseOptions;
}
