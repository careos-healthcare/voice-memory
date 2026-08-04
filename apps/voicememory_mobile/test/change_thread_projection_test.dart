import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/changes/change_correction_admission.dart';
import 'package:voicememory_mobile/features/changes/change_thread.dart';
import 'package:voicememory_mobile/features/changes/change_thread_correction.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/changes/change_thread_store.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('ChangeThreadProjector statuses', () {
    test('a repeat keeps one thread rather than a second card', () {
      final first = _entry('repeat-1', 'I paused before the work reply.', 1);
      final second = _entry(
        'repeat-2',
        'I paused before another work reply.',
        2,
      );

      final projection = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [first, second],
        conclusions: [
          _conclusion(
            id: 'repeat',
            kind: ExplainableInsightKind.pattern,
            statement: 'Pausing before a work reply may be repeating.',
            evidence: [
              _citation(first, temporalRole: EvidenceTemporalRole.then),
              _citation(second, temporalRole: EvidenceTemporalRole.now),
            ],
          ),
        ],
      );

      expect(projection.threads, hasLength(1));
      final view = projection.threads.single;
      expect(view.thread.currentStatus, ChangeThreadStatus.repeated);
      expect(view.savedMomentCount, 2);
      expect(view.thread.subjectRepresentation, contains('reply'));
    });

    test('two findings on one subject update the same thread', () {
      final entries = [
        _entry('a', 'I answered the work message immediately.', 1),
        _entry('b', 'I paused before answering the work message.', 2),
        _entry('c', 'I paused again before answering the work message.', 3),
      ];

      final projection = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: entries,
        conclusions: [
          _conclusion(
            id: 'change-1',
            kind: ExplainableInsightKind.change,
            statement: 'Your work message response may have changed.',
            evidence: [
              _citation(entries[0], temporalRole: EvidenceTemporalRole.then),
              _citation(entries[1], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
          _conclusion(
            id: 'change-2',
            kind: ExplainableInsightKind.change,
            statement: 'Your work message response may have changed again.',
            evidence: [
              _citation(entries[0], temporalRole: EvidenceTemporalRole.then),
              _citation(entries[2], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
        ],
      );

      expect(projection.threads, hasLength(1));
      expect(projection.threads.single.events, hasLength(2));
      expect(projection.threads.single.savedMomentCount, 3);
    });

    test('replaced wording reads as changed', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );

      final projection = _projectChange(then, now);

      expect(
        projection.threads.single.thread.currentStatus,
        ChangeThreadStatus.changed,
      );
    });

    test('a graded dimension moving up reads as strengthened', () {
      final then = _entry(
        'then',
        'My work response felt worried and uncertain.',
        1,
      );
      final now = _entry('now', 'My work response felt calm and certain.', 2);

      final projection = _projectChange(then, now);

      expect(
        projection.threads.single.thread.currentStatus,
        ChangeThreadStatus.strengthened,
      );
    });

    test('a graded dimension moving down reads as weakened', () {
      final then = _entry('then', 'My work response felt calm and certain.', 1);
      final now = _entry(
        'now',
        'My work response felt worried and uncertain.',
        2,
      );

      final projection = _projectChange(then, now);

      expect(
        projection.threads.single.thread.currentStatus,
        ChangeThreadStatus.weakened,
      );
    });

    test(
      'a finding two threads can equally claim stays unresolved and ungrouped',
      () {
        final entries = [
          _entry('m1', 'I paused before the morning email reply.', 1),
          _entry('m2', 'I paused before another morning email reply.', 2),
          _entry('e1', 'I paused before the evening phone message.', 3),
          _entry('e2', 'I paused before another evening phone message.', 4),
          _entry('x1', 'I paused and sent the reply message quickly.', 5),
          _entry('x2', 'I paused and sent the reply message for hours.', 6),
        ];
        final projection = ChangeThreadProjector.project(
          archiveId: 'local',
          entries: entries,
          conclusions: [
            _conclusion(
              id: 'morning',
              kind: ExplainableInsightKind.pattern,
              statement:
                  'Pausing before a morning email reply may be repeating.',
              evidence: [
                _citation(entries[0], temporalRole: EvidenceTemporalRole.then),
                _citation(entries[1], temporalRole: EvidenceTemporalRole.now),
              ],
            ),
            _conclusion(
              id: 'evening',
              kind: ExplainableInsightKind.pattern,
              statement:
                  'Pausing before an evening phone message may be repeating.',
              evidence: [
                _citation(entries[2], temporalRole: EvidenceTemporalRole.then),
                _citation(entries[3], temporalRole: EvidenceTemporalRole.now),
              ],
            ),
            _conclusion(
              id: 'ambiguous',
              kind: ExplainableInsightKind.change,
              statement:
                  'The reply message wording shifted from quickly to hours.',
              evidence: [
                _citation(entries[4], temporalRole: EvidenceTemporalRole.then),
                _citation(entries[5], temporalRole: EvidenceTemporalRole.now),
              ],
            ),
          ],
        );

        expect(projection.threads, hasLength(2));
        expect(projection.ungroupedEvents.map((event) => event.eventId), [
          'ambiguous',
        ]);
        expect(
          projection.ungroupedEvents.single.status,
          ChangeThreadStatus.unresolved,
        );
      },
    );

    test('identity is not the first alphabetically shared word', () {
      final work = [
        _entry('w1', 'I answered the work message immediately.', 1),
        _entry('w2', 'I paused before answering the work message.', 2),
      ];
      final review = [
        _entry('r1', 'I answered the review comment immediately.', 3),
        _entry('r2', 'I paused before answering the review comment.', 4),
      ];

      final projection = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [...work, ...review],
        conclusions: [
          _conclusion(
            id: 'work-change',
            kind: ExplainableInsightKind.change,
            statement: 'Your work message response may have changed.',
            evidence: [
              _citation(work[0], temporalRole: EvidenceTemporalRole.then),
              _citation(work[1], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
          _conclusion(
            id: 'review-change',
            kind: ExplainableInsightKind.change,
            statement: 'Your review comment response may have changed.',
            evidence: [
              _citation(review[0], temporalRole: EvidenceTemporalRole.then),
              _citation(review[1], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
        ],
      );

      // "answer" is shared by both pairs and sorts first alphabetically. The
      // old shared-first-word rule would have fused these into one thread.
      expect(projection.threads, hasLength(2));
      expect(
        projection.threads.map((view) => view.thread.threadId).toSet(),
        hasLength(2),
      );
    });

    test('re-projecting the same archive produces no duplicate events', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );

      final first = _projectChange(then, now);
      final second = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, now],
        conclusions: [_change(then, now)],
        existingThreads: first.threads.map((view) => view.thread),
      );

      expect(second.threads, hasLength(1));
      expect(second.threads.single.events, hasLength(1));
      expect(
        second.threads.single.thread.threadId,
        first.threads.single.thread.threadId,
      );
      expect(
        second.allEvents.map((event) => event.eventId).toList(),
        first.allEvents.map((event) => event.eventId).toList(),
      );
    });

    test('a deleted source drops the finding instead of quoting a ghost', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      final deleted = now.copyWith(deletedAt: DateTime.utc(2026, 7, 9));

      final projection = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, deleted],
        conclusions: [_change(then, now)],
      );

      expect(projection.threads, isEmpty);
      expect(projection.ungroupedEvents, isEmpty);
    });

    test('contradicting evidence survives the durable event record', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      final contradiction = _entry(
        'counter',
        'I still answered one work message immediately.',
        3,
      );
      final event = ChangeEvent(
        eventId: 'change-with-counterevidence',
        threadId: 'work',
        conclusionKind: ExplainableInsightKind.change,
        status: ChangeThreadStatus.changed,
        changedDimensions: const [],
        exactEvidence: [
          _citation(then, temporalRole: EvidenceTemporalRole.then),
          _citation(now, temporalRole: EvidenceTemporalRole.now),
          _citation(contradiction, role: TranscriptEvidenceRole.contradicting),
        ],
        occurredAt: now.createdAt,
        confidenceBand: EvidenceConfidenceBand.earlyObservation,
        uncertainty: 'The evidence includes a contradiction.',
        alternativeExplanation: '',
      );

      final restored = ChangeEvent.fromJson(event.toJson())!;
      expect(restored.exactEvidence, hasLength(3));
      expect(restored.contradictingEvidence.single.entryId, 'counter');
      expect(restored.nowEvidence.entryId, 'now');
    });

    test('threads are archive scoped', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );

      final mine = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, now],
        conclusions: [_change(then, now)],
      );
      final theirs = ChangeThreadProjector.project(
        archiveId: 'other-account',
        entries: [then, now],
        conclusions: [_change(then, now)],
      );

      expect(mine.threads, hasLength(1));
      expect(mine.threads.single.thread.archiveId, 'local');
      expect(theirs.threads, isEmpty);
      expect(theirs.ungroupedEvents, isEmpty);
    });
  });

  group('user corrections', () {
    test('renaming a thread keeps the label and marks the correction', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      final base = _projectChange(then, now);
      final threadId = base.threads.single.thread.threadId;

      final corrected = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, now],
        conclusions: [_change(then, now)],
        corrections: [
          RenameChangeThread(
            threadId: threadId,
            label: 'Replying to work under pressure',
            at: DateTime.utc(2026, 7, 10),
          ),
        ],
      );

      final thread = corrected.threads.single.thread;
      expect(thread.userEditableLabel, 'Replying to work under pressure');
      expect(thread.correctionState, ChangeThreadCorrectionState.renamed);
      expect(corrected.threads.single.correctionMarker, 'Renamed by you');
      expect(thread.labelIsUserConfirmed, isTrue);
    });

    // The paywall is allowed to name a thread only when this flag is true, so
    // a derived label defaulting to "confirmed" would leak inferred content
    // onto a commercial surface.
    test('a derived label is never treated as user confirmed', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );

      final projection = _projectChange(then, now);

      expect(projection.threads, isNotEmpty);
      for (final view in projection.threads) {
        expect(
          view.thread.labelIsUserConfirmed,
          isFalse,
          reason:
              'ArchiveMe named "${view.thread.userEditableLabel}", not the '
              'user, so it must not be presentable as an approved label.',
        );
      }
    });

    test(
      'splitting moves the wrongly grouped moments into their own thread',
      () {
        final entries = [
          _entry('a', 'I answered the work message immediately.', 1),
          _entry('b', 'I paused before answering the work message.', 2),
          _entry('c', 'I paused again before answering the work message.', 3),
        ];
        final conclusions = [
          _conclusion(
            id: 'change-1',
            kind: ExplainableInsightKind.change,
            statement: 'Your work message response may have changed.',
            evidence: [
              _citation(entries[0], temporalRole: EvidenceTemporalRole.then),
              _citation(entries[1], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
          _conclusion(
            id: 'change-2',
            kind: ExplainableInsightKind.change,
            statement: 'Your work message response may have changed again.',
            evidence: [
              _citation(entries[0], temporalRole: EvidenceTemporalRole.then),
              _citation(entries[2], temporalRole: EvidenceTemporalRole.now),
            ],
          ),
        ];
        final grouped = ChangeThreadProjector.project(
          archiveId: 'local',
          entries: entries,
          conclusions: conclusions,
        );
        final threadId = grouped.threads.single.thread.threadId;

        final split = ChangeThreadProjector.project(
          archiveId: 'local',
          entries: entries,
          conclusions: conclusions,
          corrections: [
            SplitChangeThread(
              threadId: threadId,
              eventIds: const {'change-2'},
              newLabel: 'A different work thing',
              at: DateTime.utc(2026, 7, 10),
            ),
          ],
        );

        expect(split.threads, hasLength(2));
        final moved = split.threads.firstWhere(
          (view) => view.thread.userEditableLabel == 'A different work thing',
        );
        expect(moved.events.map((event) => event.eventId), ['change-2']);
        expect(moved.thread.correctionState, ChangeThreadCorrectionState.split);
        final kept = split.threads.firstWhere(
          (view) => view.thread.threadId == threadId,
        );
        expect(kept.events.map((event) => event.eventId), ['change-1']);
      },
    );

    test('merging is refused when two threads share no subject', () {
      final work = [
        _entry('w1', 'I answered the work message immediately.', 1),
        _entry('w2', 'I paused before answering the work message.', 2),
      ];
      final garden = [
        _entry('g1', 'I was unsure about the garden tomatoes.', 3),
        _entry('g2', 'I was certain about the garden tomatoes.', 4),
      ];
      final entries = [...work, ...garden];
      final conclusions = [
        _conclusion(
          id: 'work-change',
          kind: ExplainableInsightKind.change,
          statement: 'Your work message response may have changed.',
          evidence: [
            _citation(work[0], temporalRole: EvidenceTemporalRole.then),
            _citation(work[1], temporalRole: EvidenceTemporalRole.now),
          ],
        ),
        _conclusion(
          id: 'garden-change',
          kind: ExplainableInsightKind.change,
          statement:
              'The garden tomatoes wording moved from unsure to certain.',
          evidence: [
            _citation(garden[0], temporalRole: EvidenceTemporalRole.then),
            _citation(garden[1], temporalRole: EvidenceTemporalRole.now),
          ],
        ),
      ];
      final base = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: entries,
        conclusions: conclusions,
      );
      expect(base.threads, hasLength(2));

      final merged = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: entries,
        conclusions: conclusions,
        corrections: [
          MergeChangeThreads(
            threadId: base.threads.first.thread.threadId,
            intoThreadId: base.threads.last.thread.threadId,
            at: DateTime.utc(2026, 7, 20),
          ),
        ],
      );

      expect(merged.threads, hasLength(2));
    });

    test('merge admission preserves a user-confirmed source label', () {
      final admission = ChangeCorrectionAdmission.merge(
        _thread(
          id: 'source',
          label: 'My work replies',
          subject: const {'work', 'reply'},
          labelIsUserConfirmed: true,
        ),
        _thread(
          id: 'into',
          label: 'Reply work',
          subject: const {'work', 'reply', 'email'},
        ),
      );

      expect(admission.allowed, isTrue);
      expect(admission.resultingLabel, 'My work replies');
    });

    test('merge admission names every durable refusal', () {
      final visible = _thread(
        id: 'visible',
        label: 'Work replies',
        subject: const {'work', 'reply'},
      );

      expect(
        ChangeCorrectionAdmission.merge(
          visible,
          _thread(
            id: 'other-archive',
            archiveId: 'other',
            label: 'Work replies',
            subject: const {'work', 'reply'},
          ),
        ).refusal,
        ChangeMergeRefusal.archiveMismatch,
      );
      expect(
        ChangeCorrectionAdmission.merge(
          visible.copyWith(
            visibilityState: ChangeThreadVisibility.suppressed,
            correctionState: ChangeThreadCorrectionState.framingSuppressed,
          ),
          visible,
        ).refusal,
        ChangeMergeRefusal.incompatibleSuppression,
      );
      expect(
        ChangeCorrectionAdmission.merge(
          visible,
          _thread(id: 'garden', label: 'Garden', subject: const {'garden'}),
        ).refusal,
        ChangeMergeRefusal.noSubjectOverlap,
      );
    });

    test('suppressing a framing hides the thread without touching moments', () {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      final base = _projectChange(then, now);

      final suppressed = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, now],
        conclusions: [_change(then, now)],
        corrections: [
          SuppressChangeThreadFraming(
            threadId: base.threads.single.thread.threadId,
            at: DateTime.utc(2026, 7, 10),
          ),
        ],
      );

      expect(suppressed.threads, isEmpty);
    });
  });

  group('ChangeThreadStore', () {
    late Directory directory;
    late List<int> sharedKey;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('change_thread_test_');
      sharedKey = List<int>.generate(32, (index) => index + 3);
    });

    tearDown(() => directory.delete(recursive: true));

    ChangeThreadStore open({String archiveId = 'local'}) => ChangeThreadStore(
      file: File('${directory.path}/threads.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: sharedKey),
      archiveId: archiveId,
      clock: () => DateTime.utc(2026, 8, 2),
    );

    test('threads and corrections survive a restart', () async {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      final projection = _projectChange(then, now);
      final threadId = projection.threads.single.thread.threadId;

      await open().save(projection);
      await open().renameThread(threadId, 'Work replies');

      final reopened = await open().read();
      expect(reopened.threads, hasLength(1));
      expect(reopened.threads.single.threadId, threadId);
      expect(reopened.events.map((event) => event.eventId), [
        'change-then-now',
      ]);
      expect(reopened.corrections, hasLength(1));
      expect(reopened.projection.threads, hasLength(1));

      final replayed = ChangeThreadProjector.project(
        archiveId: 'local',
        entries: [then, now],
        conclusions: [_change(then, now)],
        corrections: reopened.corrections,
        existingThreads: reopened.threads,
      );
      expect(replayed.threads.single.thread.userEditableLabel, 'Work replies');
      expect(replayed.threads.single.events, hasLength(1));
    });

    test('one archive never reads another archive threads', () async {
      final then = _entry(
        'then',
        'I answered the work message immediately.',
        1,
      );
      final now = _entry(
        'now',
        'I paused before answering the work message.',
        2,
      );
      await open().save(_projectChange(then, now));

      final other = await open(archiveId: 'other-account').read();

      expect(other.threads, isEmpty);
      expect(other.events, isEmpty);
      expect(other.corrections, isEmpty);
      expect((await open().read()).threads, hasLength(1));
    });
  });

  test('an existing thread stays readable after Pro expiry', () {
    final then = _entry('then', 'I answered the work message immediately.', 1);
    final now = _entry('now', 'I paused before answering the work message.', 2);
    final projection = _projectChange(then, now);

    const expired = EntitlementSnapshot(
      plan: PlanKind.free,
      status: EntitlementStatus.expired,
    );
    final read = AccessPolicyEngine.decide(
      capability: CapabilityId.readExistingGeneratedOutput,
      entitlement: expired,
    );

    expect(read.allowed, isTrue);
    expect(projection.threads.single.events.single.exactEvidence, hasLength(2));
    expect(
      projection.threads.single.strongestEvidenceExcerpt,
      'I paused before answering the work message.',
    );
  });
}

ChangeThread _thread({
  required String id,
  required String label,
  required Set<String> subject,
  String archiveId = 'local',
  bool labelIsUserConfirmed = false,
}) => ChangeThread(
  threadId: id,
  archiveId: archiveId,
  userEditableLabel: label,
  subjectRepresentation: subject,
  firstObservedAt: DateTime.utc(2026, 7, 1),
  latestObservedAt: DateTime.utc(2026, 7, 2),
  currentStatus: ChangeThreadStatus.changed,
  evidenceEventIds: const ['event'],
  policyVersion: ChangeThreadProjector.policyVersion,
  labelIsUserConfirmed: labelIsUserConfirmed,
);

ChangeThreadProjection _projectChange(JournalEntry then, JournalEntry now) =>
    ChangeThreadProjector.project(
      archiveId: 'local',
      entries: [then, now],
      conclusions: [_change(then, now)],
    );

ExplainableConclusion _change(JournalEntry then, JournalEntry now) =>
    _conclusion(
      id: 'change-${then.id}-${now.id}',
      kind: ExplainableInsightKind.change,
      statement: 'The work response may have changed.',
      evidence: [
        _citation(then, temporalRole: EvidenceTemporalRole.then),
        _citation(now, temporalRole: EvidenceTemporalRole.now),
      ],
    );

JournalEntry _entry(String id, String transcript, int day) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, day),
  transcript: transcript,
  durationSeconds: 0,
  source: SavedMomentSource.typed,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

TranscriptEvidenceCitation _citation(
  JournalEntry entry, {
  EvidenceTemporalRole temporalRole = EvidenceTemporalRole.single,
  TranscriptEvidenceRole role = TranscriptEvidenceRole.supporting,
}) => TranscriptEvidenceCitation(
  entryId: entry.id,
  quote: entry.transcript,
  startUtf16: 0,
  endUtf16: entry.transcript.length,
  role: role,
  sourceCapturedAt: entry.createdAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
);

ExplainableConclusion _conclusion({
  required String id,
  required ExplainableInsightKind kind,
  required String statement,
  required List<TranscriptEvidenceCitation> evidence,
}) => ExplainableConclusion(
  id: id,
  kind: kind,
  statement: statement,
  confidence: evidence.length == 1 ? 65 : 75,
  reasoning: const ['The exact saved wording supports this narrow claim.'],
  uncertaintyNote: 'Later saved moments may support or challenge this read.',
  evidence: evidence,
  alternatives: const [
    ExplainableAlternative(
      statement: 'The circumstances may explain this wording.',
      rationale: 'More saved moments could support a different explanation.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'test',
    generatedAt: DateTime.utc(2026, 8),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
);
