/// Fixed response ids for quick capture friction check.
abstract final class QuickCaptureFrictionResponseIds {
  QuickCaptureFrictionResponseIds._();

  static const quickEnough = 'quick_enough';
  static const mostly = 'mostly';
  static const stillWork = 'still_work';
  static const notSure = 'not_sure';

  static const all = [quickEnough, mostly, stillWork, notSure];
}

/// Source tag for friction records.
abstract final class QuickCaptureFrictionSource {
  QuickCaptureFrictionSource._();

  static const quickYesCapture = 'quick_yes_capture';
}

enum QuickCaptureFrictionStatus { answered, skipped }

/// Local friction record — fixed ids and entry link only.
class QuickCaptureFrictionRecord {
  const QuickCaptureFrictionRecord({
    required this.responseId,
    required this.source,
    required this.relatedEntryId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String responseId;
  final String source;
  final String relatedEntryId;
  final QuickCaptureFrictionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAnswered =>
      status == QuickCaptureFrictionStatus.answered && responseId.isNotEmpty;

  bool get isSkipped => status == QuickCaptureFrictionStatus.skipped;

  bool get isComplete => isAnswered || isSkipped;

  bool get isStillWork =>
      isAnswered && responseId == QuickCaptureFrictionResponseIds.stillWork;

  Map<String, dynamic> toJson() => {
    'responseId': responseId,
    'source': source,
    'relatedEntryId': relatedEntryId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static QuickCaptureFrictionRecord? fromJson(Map<String, dynamic> json) {
    final source = json['source'];
    final statusRaw = json['status'];
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    if (source is! String || source.isEmpty) return null;
    if (statusRaw is! String) return null;
    if (createdAtRaw is! String || updatedAtRaw is! String) return null;
    final createdAt = DateTime.tryParse(createdAtRaw);
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (createdAt == null || updatedAt == null) return null;
    final status = switch (statusRaw) {
      'answered' => QuickCaptureFrictionStatus.answered,
      'skipped' => QuickCaptureFrictionStatus.skipped,
      _ => null,
    };
    if (status == null) return null;
    final responseId = json['responseId'];
    final relatedEntryId = json['relatedEntryId'];
    return QuickCaptureFrictionRecord(
      responseId: responseId is String ? responseId : '',
      source: source,
      relatedEntryId: relatedEntryId is String ? relatedEntryId : '',
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Engine input — local flags only.
class QuickCaptureFrictionInput {
  const QuickCaptureFrictionInput({
    required this.capacityWedgeActive,
    required this.sampleMode,
    required this.screenshotMode,
    required this.hasQuickCaptureEntry,
    required this.showAfterQuickSave,
    this.record,
  });

  final bool capacityWedgeActive;
  final bool sampleMode;
  final bool screenshotMode;
  final bool hasQuickCaptureEntry;
  final bool showAfterQuickSave;
  final QuickCaptureFrictionRecord? record;
}

/// Card result — no journal text.
class QuickCaptureFrictionResult {
  const QuickCaptureFrictionResult({
    required this.showCard,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.responseIds,
    required this.relatedEntryId,
  });

  static const hidden = QuickCaptureFrictionResult(
    showCard: false,
    title: '',
    body: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    responseIds: [],
    relatedEntryId: '',
  );

  final bool showCard;
  final String title;
  final String body;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final List<String> responseIds;
  final String relatedEntryId;
}
