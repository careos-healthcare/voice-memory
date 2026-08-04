import '../explainable_conclusion/change_dimensions.dart';
import '../explainable_conclusion/explainable_conclusion.dart';

/// How a thread stands right now, in the reader's language.
///
/// There is no "corrected" status: a correction is something the user did to
/// a thread, not a finding about their life, so it travels on
/// [ChangeThreadCorrectionState] instead.
enum ChangeThreadStatus {
  firstObserved,
  repeated,
  changed,
  weakened,
  strengthened,
  unresolved,
}

extension ChangeThreadStatusLabel on ChangeThreadStatus {
  String get label => switch (this) {
    ChangeThreadStatus.firstObserved => 'First observed',
    ChangeThreadStatus.repeated => 'Came up again',
    ChangeThreadStatus.changed => 'Something changed',
    ChangeThreadStatus.weakened => 'Eased off',
    ChangeThreadStatus.strengthened => 'Grew stronger',
    ChangeThreadStatus.unresolved => 'Not settled',
  };
}

enum ChangeThreadCorrectionState {
  none,
  renamed,
  split,
  merged,
  framingSuppressed,
  correctedByUser,
}

extension ChangeThreadCorrectionStateLabel on ChangeThreadCorrectionState {
  String? get marker => switch (this) {
    ChangeThreadCorrectionState.none => null,
    ChangeThreadCorrectionState.renamed => 'Renamed by you',
    ChangeThreadCorrectionState.split => 'Split by you',
    ChangeThreadCorrectionState.merged => 'Merged by you',
    ChangeThreadCorrectionState.framingSuppressed => 'Hidden by you',
    ChangeThreadCorrectionState.correctedByUser => 'Corrected by you',
  };
}

enum ChangeThreadVisibility { visible, suppressed }

/// One dated finding inside a thread, bound to the words that produced it.
class ChangeEvent {
  ChangeEvent({
    required this.eventId,
    required this.threadId,
    required this.conclusionKind,
    required this.status,
    required Iterable<ChangeDimension> changedDimensions,
    required Iterable<TranscriptEvidenceCitation> exactEvidence,
    required this.occurredAt,
    required this.confidenceBand,
    required this.uncertainty,
    required this.alternativeExplanation,
    this.statement = '',
    this.correctionState = ChangeThreadCorrectionState.none,
  }) : changedDimensions = List.unmodifiable(changedDimensions),
       exactEvidence = List.unmodifiable(exactEvidence),
       assert(eventId != ''),
       assert(exactEvidence.isNotEmpty);

  final String eventId;
  final String threadId;
  final ExplainableInsightKind conclusionKind;
  final ChangeThreadStatus status;
  final List<ChangeDimension> changedDimensions;
  final List<TranscriptEvidenceCitation> exactEvidence;
  final DateTime occurredAt;
  final EvidenceConfidenceBand confidenceBand;
  final String uncertainty;
  final String alternativeExplanation;

  /// Reader-facing sentence taken verbatim from the validated conclusion.
  final String statement;

  final ChangeThreadCorrectionState correctionState;

  Set<String> get sourceEntryIds =>
      exactEvidence.map((citation) => citation.entryId).toSet();

  List<TranscriptEvidenceCitation> get supportingEvidence => exactEvidence
      .where((citation) => citation.role == TranscriptEvidenceRole.supporting)
      .toList(growable: false);

  List<TranscriptEvidenceCitation> get contradictingEvidence => exactEvidence
      .where(
        (citation) => citation.role == TranscriptEvidenceRole.contradicting,
      )
      .toList(growable: false);

  /// The Then side of a comparison, or the single cited moment.
  TranscriptEvidenceCitation get thenEvidence =>
      (supportingEvidence.isEmpty ? exactEvidence : supportingEvidence)
          .firstWhere(
            (item) => item.temporalRole == EvidenceTemporalRole.then,
            orElse: () =>
                (supportingEvidence.isEmpty
                        ? exactEvidence
                        : supportingEvidence)
                    .first,
          );

  /// The Now side of a comparison, or the single cited moment.
  TranscriptEvidenceCitation get nowEvidence =>
      (supportingEvidence.isEmpty ? exactEvidence : supportingEvidence)
          .lastWhere(
            (item) => item.temporalRole == EvidenceTemporalRole.now,
            orElse: () =>
                (supportingEvidence.isEmpty
                        ? exactEvidence
                        : supportingEvidence)
                    .last,
          );

  ChangeEvent copyWith({
    String? threadId,
    ChangeThreadStatus? status,
    ChangeThreadCorrectionState? correctionState,
  }) => ChangeEvent(
    eventId: eventId,
    threadId: threadId ?? this.threadId,
    conclusionKind: conclusionKind,
    status: status ?? this.status,
    changedDimensions: changedDimensions,
    exactEvidence: exactEvidence,
    occurredAt: occurredAt,
    confidenceBand: confidenceBand,
    uncertainty: uncertainty,
    alternativeExplanation: alternativeExplanation,
    statement: statement,
    correctionState: correctionState ?? this.correctionState,
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'threadId': threadId,
    'conclusionKind': conclusionKind.name,
    'status': status.name,
    'changedDimensions': changedDimensions
        .map((dimension) => dimension.name)
        .toList(growable: false),
    'exactEvidence': exactEvidence
        .map((citation) => citation.toJson())
        .toList(growable: false),
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'confidenceBand': confidenceBand.name,
    'uncertainty': uncertainty,
    'alternativeExplanation': alternativeExplanation,
    'statement': statement,
    'correctionState': correctionState.name,
  };

  static ChangeEvent? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final eventId = json['eventId']?.toString() ?? '';
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final evidence = (json['exactEvidence'] as List? ?? const [])
        .map(TranscriptEvidenceCitation.fromJson)
        .whereType<TranscriptEvidenceCitation>()
        .toList(growable: false);
    if (eventId.isEmpty || occurredAt == null || evidence.isEmpty) return null;
    return ChangeEvent(
      eventId: eventId,
      threadId: json['threadId']?.toString() ?? '',
      conclusionKind: _enumOf(
        ExplainableInsightKind.values,
        json['conclusionKind'],
        ExplainableInsightKind.observation,
      ),
      status: _enumOf(
        ChangeThreadStatus.values,
        json['status'],
        ChangeThreadStatus.unresolved,
      ),
      changedDimensions: (json['changedDimensions'] as List? ?? const [])
          .map(
            (name) => ChangeDimension.values
                .where((dimension) => dimension.name == name)
                .firstOrNull,
          )
          .whereType<ChangeDimension>()
          .toList(growable: false),
      exactEvidence: evidence,
      occurredAt: occurredAt.toUtc(),
      confidenceBand: _enumOf(
        EvidenceConfidenceBand.values,
        json['confidenceBand'],
        EvidenceConfidenceBand.earlyObservation,
      ),
      uncertainty: json['uncertainty']?.toString() ?? '',
      alternativeExplanation: json['alternativeExplanation']?.toString() ?? '',
      statement: json['statement']?.toString() ?? '',
      correctionState: _enumOf(
        ChangeThreadCorrectionState.values,
        json['correctionState'],
        ChangeThreadCorrectionState.none,
      ),
    );
  }
}

/// A stable line of enquiry the user can recognise and rename.
///
/// A thread is identity, not a card. The same recurring issue keeps updating
/// one thread rather than spawning a new long card every time it recurs.
class ChangeThread {
  ChangeThread({
    required this.threadId,
    required this.archiveId,
    required this.userEditableLabel,
    required Iterable<String> subjectRepresentation,
    required this.firstObservedAt,
    required this.latestObservedAt,
    required this.currentStatus,
    required Iterable<String> evidenceEventIds,
    required this.policyVersion,
    this.correctionState = ChangeThreadCorrectionState.none,
    this.visibilityState = ChangeThreadVisibility.visible,
    this.labelIsUserConfirmed = false,
  }) : subjectRepresentation = Set.unmodifiable(subjectRepresentation),
       evidenceEventIds = List.unmodifiable(evidenceEventIds),
       assert(threadId != ''),
       assert(archiveId != ''),
       assert(!latestObservedAt.isBefore(firstObservedAt));

  final String threadId;
  final String archiveId;

  /// What the user sees and may rename. Never a trait or a diagnosis.
  final String userEditableLabel;

  /// The content words that identify what this thread is about. Identity is
  /// this whole set, never one word picked out of it.
  final Set<String> subjectRepresentation;

  final DateTime firstObservedAt;
  final DateTime latestObservedAt;
  final ChangeThreadStatus currentStatus;
  final List<String> evidenceEventIds;
  final ChangeThreadCorrectionState correctionState;
  final ChangeThreadVisibility visibilityState;
  final String policyVersion;

  /// True once the user has named this thread, which pins its identity.
  final bool labelIsUserConfirmed;

  bool get isVisible => visibilityState == ChangeThreadVisibility.visible;

  ChangeThread copyWith({
    String? userEditableLabel,
    Iterable<String>? subjectRepresentation,
    DateTime? firstObservedAt,
    DateTime? latestObservedAt,
    ChangeThreadStatus? currentStatus,
    Iterable<String>? evidenceEventIds,
    ChangeThreadCorrectionState? correctionState,
    ChangeThreadVisibility? visibilityState,
    bool? labelIsUserConfirmed,
  }) => ChangeThread(
    threadId: threadId,
    archiveId: archiveId,
    userEditableLabel: userEditableLabel ?? this.userEditableLabel,
    subjectRepresentation: subjectRepresentation ?? this.subjectRepresentation,
    firstObservedAt: firstObservedAt ?? this.firstObservedAt,
    latestObservedAt: latestObservedAt ?? this.latestObservedAt,
    currentStatus: currentStatus ?? this.currentStatus,
    evidenceEventIds: evidenceEventIds ?? this.evidenceEventIds,
    correctionState: correctionState ?? this.correctionState,
    visibilityState: visibilityState ?? this.visibilityState,
    policyVersion: policyVersion,
    labelIsUserConfirmed: labelIsUserConfirmed ?? this.labelIsUserConfirmed,
  );

  Map<String, dynamic> toJson() => {
    'threadId': threadId,
    'archiveId': archiveId,
    'userEditableLabel': userEditableLabel,
    'subjectRepresentation': subjectRepresentation.toList(growable: false)
      ..sort(),
    'firstObservedAt': firstObservedAt.toUtc().toIso8601String(),
    'latestObservedAt': latestObservedAt.toUtc().toIso8601String(),
    'currentStatus': currentStatus.name,
    'evidenceEventIds': evidenceEventIds,
    'correctionState': correctionState.name,
    'visibilityState': visibilityState.name,
    'policyVersion': policyVersion,
    if (labelIsUserConfirmed) 'labelIsUserConfirmed': true,
  };

  static ChangeThread? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final threadId = json['threadId']?.toString() ?? '';
    final archiveId = json['archiveId']?.toString() ?? '';
    final first = DateTime.tryParse(json['firstObservedAt']?.toString() ?? '');
    final latest = DateTime.tryParse(
      json['latestObservedAt']?.toString() ?? '',
    );
    if (threadId.isEmpty || archiveId.isEmpty || first == null) return null;
    final firstUtc = first.toUtc();
    final latestUtc = latest?.toUtc() ?? firstUtc;
    return ChangeThread(
      threadId: threadId,
      archiveId: archiveId,
      userEditableLabel: json['userEditableLabel']?.toString() ?? threadId,
      subjectRepresentation:
          (json['subjectRepresentation'] as List? ?? const [])
              .map((item) => item.toString())
              .toSet(),
      firstObservedAt: firstUtc,
      latestObservedAt: latestUtc.isBefore(firstUtc) ? firstUtc : latestUtc,
      currentStatus: _enumOf(
        ChangeThreadStatus.values,
        json['currentStatus'],
        ChangeThreadStatus.unresolved,
      ),
      evidenceEventIds: (json['evidenceEventIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      correctionState: _enumOf(
        ChangeThreadCorrectionState.values,
        json['correctionState'],
        ChangeThreadCorrectionState.none,
      ),
      visibilityState: _enumOf(
        ChangeThreadVisibility.values,
        json['visibilityState'],
        ChangeThreadVisibility.visible,
      ),
      policyVersion: json['policyVersion']?.toString() ?? '',
      labelIsUserConfirmed: json['labelIsUserConfirmed'] == true,
    );
  }
}

/// A thread with its own events attached, ready for the Changes surface.
class ChangeThreadView {
  ChangeThreadView({
    required this.thread,
    required Iterable<ChangeEvent> events,
  }) : events = List.unmodifiable(
         events.toList()..sort((a, b) {
           final byDate = a.occurredAt.compareTo(b.occurredAt);
           return byDate != 0 ? byDate : a.eventId.compareTo(b.eventId);
         }),
       );

  final ChangeThread thread;

  /// Chronological history, oldest first.
  final List<ChangeEvent> events;

  /// Distinct saved moments behind this thread — the count the user sees.
  int get savedMomentCount =>
      {for (final event in events) ...event.sourceEntryIds}.length;

  /// The excerpt that best earns the thread's current reading: the newest
  /// event's Now side, which is the wording the status is actually about.
  String get strongestEvidenceExcerpt =>
      events.isEmpty ? '' : events.last.nowEvidence.quote;

  String? get correctionMarker => thread.correctionState.marker;
}

T _enumOf<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((value) => value.name == raw).firstOrNull ?? fallback;
