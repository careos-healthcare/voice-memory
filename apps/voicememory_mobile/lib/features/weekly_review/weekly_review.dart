import '../changes/change_copy_numbers.dart';
import '../changes/change_customer_presentation.dart';
import '../changes/change_thread.dart';
import '../explainable_conclusion/explainable_conclusion.dart';

/// The only things a weekly review is allowed to say.
///
/// There is deliberately no "insight", "advice", or "milestone" kind. A review
/// reports what the threads already show and stops.
enum WeeklyReviewItemKind {
  repeated,
  possibleChange,
  weakened,
  strengthened,
  unresolved,
  correction,
}

extension WeeklyReviewItemKindLabel on WeeklyReviewItemKind {
  ChangeThreadStatus get internalStatus => switch (this) {
    WeeklyReviewItemKind.repeated => ChangeThreadStatus.repeated,
    WeeklyReviewItemKind.possibleChange => ChangeThreadStatus.changed,
    WeeklyReviewItemKind.weakened => ChangeThreadStatus.weakened,
    WeeklyReviewItemKind.strengthened => ChangeThreadStatus.strengthened,
    WeeklyReviewItemKind.unresolved => ChangeThreadStatus.unresolved,
    WeeklyReviewItemKind.correction => ChangeThreadStatus.changed,
  };

  ChangeCustomerPresentation get presentation =>
      ChangeCustomerPresentationMapper.forStatus(internalStatus);

  String get label => presentation.primaryStatus;

  String? get secondaryExplanation => switch (this) {
    WeeklyReviewItemKind.correction => 'Corrected by you',
    _ => presentation.secondaryExplanation,
  };

  /// The clause this kind contributes to the review's one-line summary.
  String get headlineClause => switch (this) {
    WeeklyReviewItemKind.repeated => 'one is showing up again',
    WeeklyReviewItemKind.possibleChange ||
    WeeklyReviewItemKind.weakened ||
    WeeklyReviewItemKind.strengthened => 'one changed',
    WeeklyReviewItemKind.unresolved => 'one change is mixed or uncertain',
    WeeklyReviewItemKind.correction => 'one was corrected by you',
  };
}

/// One line of a weekly review, welded to the moments that produced it.
///
/// [evidence] cannot be empty, so no item can exist without exact words behind
/// it, and [threadId] always points back into Changes.
class WeeklyReviewItem {
  WeeklyReviewItem({
    required this.kind,
    required this.threadId,
    required this.threadLabel,
    required this.eventId,
    required this.statement,
    required Iterable<TranscriptEvidenceCitation> evidence,
    required this.occurredAt,
  }) : evidence = List.unmodifiable(evidence),
       assert(threadId != '', 'A review item must link back to a thread.'),
       assert(
         evidence.isNotEmpty,
         'A review item must cite the exact moments behind it.',
       );

  final WeeklyReviewItemKind kind;

  /// The thread this item opens in Changes. Changes stays the source of truth.
  final String threadId;
  final String threadLabel;
  final String eventId;

  /// Taken verbatim from the already-validated finding, never rewritten here.
  final String statement;

  final List<TranscriptEvidenceCitation> evidence;
  final DateTime occurredAt;

  Set<String> get sourceEntryIds =>
      evidence.map((citation) => citation.entryId).toSet();

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'threadId': threadId,
    'threadLabel': threadLabel,
    'eventId': eventId,
    'statement': statement,
    'evidence': evidence
        .map((citation) => citation.toJson())
        .toList(growable: false),
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  static WeeklyReviewItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final threadId = json['threadId']?.toString() ?? '';
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final evidence = (json['evidence'] as List? ?? const [])
        .map(TranscriptEvidenceCitation.fromJson)
        .whereType<TranscriptEvidenceCitation>()
        .toList(growable: false);
    if (threadId.isEmpty || occurredAt == null || evidence.isEmpty) return null;
    final kind = WeeklyReviewItemKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    return WeeklyReviewItem(
      kind: kind,
      threadId: threadId,
      threadLabel: json['threadLabel']?.toString() ?? threadId,
      eventId: json['eventId']?.toString() ?? '',
      statement: json['statement']?.toString() ?? '',
      evidence: evidence,
      occurredAt: occurredAt.toUtc(),
    );
  }
}

/// A generated weekly review, or the explicit absence of one.
class WeeklyReview {
  WeeklyReview({
    required this.reviewId,
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required Iterable<WeeklyReviewItem> items,
    this.policyVersion = WeeklyReview.currentPolicyVersion,
  }) : items = List.unmodifiable(items),
       assert(reviewId != ''),
       assert(
         items.isNotEmpty,
         'A review with nothing to report is not shown.',
       );

  static const currentPolicyVersion = 'weekly_review_v1';

  final String reviewId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final List<WeeklyReviewItem> items;
  final String policyVersion;

  bool get hasShowingUpAgain =>
      items.any((item) => item.kind == WeeklyReviewItemKind.repeated);

  bool get hasChanged => items.any(
    (item) =>
        item.kind == WeeklyReviewItemKind.possibleChange ||
        item.kind == WeeklyReviewItemKind.weakened ||
        item.kind == WeeklyReviewItemKind.strengthened,
  );

  bool get hasUnresolvedTension =>
      items.any((item) => item.kind == WeeklyReviewItemKind.unresolved);

  /// Explicit absences stop the review implying that every section existed.
  List<String> get absentSectionExplanations => [
    if (!hasShowingUpAgain) 'Nothing was selected as Showing up again.',
    if (!hasChanged) 'Nothing was selected as Changed.',
    if (!hasUnresolvedTension) 'No mixed or uncertain change was selected.',
  ];

  /// Every thread this review points at, in display order.
  List<String> get threadIds =>
      {for (final item in items) item.threadId}.toList(growable: false);

  /// The one restrained line at the top. Built only from kinds that are
  /// actually present, so it can never claim more than the evidence shows.
  String get headline {
    final clauses = <String>[
      if (hasShowingUpAgain) WeeklyReviewItemKind.repeated.headlineClause,
      if (hasChanged)
        items
            .firstWhere(
              (item) =>
                  item.kind == WeeklyReviewItemKind.possibleChange ||
                  item.kind == WeeklyReviewItemKind.weakened ||
                  item.kind == WeeklyReviewItemKind.strengthened,
            )
            .kind
            .headlineClause,
      if (hasUnresolvedTension) WeeklyReviewItemKind.unresolved.headlineClause,
    ];
    final shown = clauses.take(_maximumHeadlineClauses).toList(growable: false);
    if (shown.length == 1) return 'This week, ${shown.single}.';
    final head = shown.sublist(0, shown.length - 1).join(', ');
    return 'This week, $head and ${shown.last}.';
  }

  /// A factual count of what the review rests on, never a score.
  String get evidenceSummary {
    final moments = {for (final item in items) ...item.sourceEntryIds}.length;
    return '${spelledCount(items.length)} '
        '${items.length == 1 ? 'item' : 'items'} · '
        '${spelledCount(moments)} saved '
        '${moments == 1 ? 'moment' : 'moments'}';
  }

  static const _maximumHeadlineClauses = 3;

  Map<String, dynamic> toJson() => {
    'reviewId': reviewId,
    'windowStart': windowStart.toUtc().toIso8601String(),
    'windowEnd': windowEnd.toUtc().toIso8601String(),
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'policyVersion': policyVersion,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  static WeeklyReview? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final reviewId = json['reviewId']?.toString() ?? '';
    final windowStart = DateTime.tryParse(
      json['windowStart']?.toString() ?? '',
    );
    final windowEnd = DateTime.tryParse(json['windowEnd']?.toString() ?? '');
    final generatedAt = DateTime.tryParse(
      json['generatedAt']?.toString() ?? '',
    );
    final items = (json['items'] as List? ?? const [])
        .map(WeeklyReviewItem.fromJson)
        .whereType<WeeklyReviewItem>()
        .toList(growable: false);
    if (reviewId.isEmpty ||
        windowStart == null ||
        windowEnd == null ||
        generatedAt == null ||
        items.isEmpty) {
      return null;
    }
    return WeeklyReview(
      reviewId: reviewId,
      windowStart: windowStart.toUtc(),
      windowEnd: windowEnd.toUtc(),
      generatedAt: generatedAt.toUtc(),
      items: items,
      policyVersion: json['policyVersion']?.toString() ?? currentPolicyVersion,
    );
  }
}

abstract final class WeeklyReviewCopy {
  WeeklyReviewCopy._();

  static const entryPointTitle = 'Your week';
  static const openCta = 'Open this week';
  static const screenTitle = 'This week';
  static const evidenceHeading = 'The words behind this';
  static const openThreadCta = 'Open in Changes';
  static const openMomentCta = 'Open the exact moment';
  static const notificationOptInLabel = 'Tell me when a weekly review is ready';
  static const notificationOptInHelper =
      'Off by default. ArchiveMe never puts your own words in a notification.';
}
