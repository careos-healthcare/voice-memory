import 'dart:convert';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_analytics.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_cache.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_candidate.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _transcript = 'I checked the numbers again before I decided anything.';
const _editedTranscript = 'I checked the numbers again before I gave up on it.';
const _quote = 'checked the numbers again';
const _statement = 'You look at the numbers before you decide.';

final _createdAt = DateTime.utc(2026, 7);

String _sha256Hex(String value) =>
    sha256.convert(utf8.encode(value)).toString();

/// A digest that counts how often it was asked to hash something, so a cache hit
/// can be proven to have avoided the work rather than merely returned the same
/// answer.
class _DigestSpy {
  _DigestSpy(this._digest);

  final String Function(String value) _digest;
  int calls = 0;

  String call(String value) {
    calls += 1;
    return _digest(value);
  }
}

ProofSourceEntry _entry({
  String entryId = 'entry-1',
  String archiveScope = 'archive-a',
  String ownerScope = 'owner-1',
  String transcript = _transcript,
  String transcriptRevision = 'rev-1',
  DateTime? createdAt,
  ProofSourceType sourceType = ProofSourceType.userVoiceTranscript,
  bool deleted = false,
  bool archived = false,
  bool allowedByArchivePolicy = true,
  bool remoteProcessingConsented = true,
}) => ProofSourceEntry(
  entryId: entryId,
  archiveScope: archiveScope,
  ownerScope: ownerScope,
  transcript: transcript,
  transcriptRevision: transcriptRevision,
  createdAt: createdAt ?? _createdAt,
  sourceType: sourceType,
  deleted: deleted,
  archived: archived,
  allowedByArchivePolicy: allowedByArchivePolicy,
  remoteProcessingConsented: remoteProcessingConsented,
);

ProofFeatureVector _vector({int citationCount = 1}) => ProofFeatureVector(
  coverage: 1,
  specificity: 1,
  citationCount: citationCount,
  sourceCount: 1,
  chronology: 1,
  sourceDiversity: 1,
  citationSourceRatio: 1,
  corroborationRatio: 1,
  contradiction: 0,
  recency: 1,
  freshness: 1,
  transcriptSpecificity: 1,
  userConfirmed: false,
  correctionHistoryCount: 0,
  acceptedCorrectionRatio: 0,
  positiveCorrectionHistory: 0,
  negativeCorrectionHistory: 0,
  wordingRejectionHistory: 0,
  evidenceRejectionHistory: 0,
  oneEntryPenalty: false,
  stalePenalty: false,
  modelConfidence: 0,
  deterministicFallback: 0,
);

void main() {
  group('source revision index', () {
    test('an unchanged entry is not hashed twice', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      final entry = _entry();

      final first = cache.revisionFor(entry);
      final second = cache.revisionFor(entry);

      expect(spy.calls, 1, reason: 'the second read must not rehash');
      expect(cache.hitCount, 1);
      expect(cache.missCount, 1);
      expect(second.transcriptFingerprint, first.transcriptFingerprint);
      expect(first.transcriptFingerprint, _sha256Hex(_transcript));
    });

    test('an equal transcript in a new string instance still hits', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      // A rebuild that re-decoded the archive hands over equal-but-distinct
      // strings; that is a hit, not a rehash.
      final rebuilt = String.fromCharCodes(_transcript.codeUnits);

      cache.revisionFor(_entry());
      expect(identical(rebuilt, _transcript), isFalse);
      final second = cache.revisionFor(_entry(transcript: rebuilt));

      expect(spy.calls, 1);
      expect(second.transcriptFingerprint, _sha256Hex(_transcript));
    });

    test('a changed transcript invalidates even when the revision did not', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);

      final before = cache.revisionFor(_entry());
      final after = cache.revisionFor(_entry(transcript: _editedTranscript));

      expect(spy.calls, 2, reason: 'edited text must be rehashed');
      expect(after.transcriptFingerprint, isNot(before.transcriptFingerprint));
      expect(after.transcriptFingerprint, _sha256Hex(_editedTranscript));
      expect(cache.hitCount, 0);
    });

    test('a same-length transcript edit is never mistaken for a hit', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      const original = 'I felt calm about the review this morning.';
      const edited = 'I felt calm about the review this evening!';
      expect(edited.length, original.length);

      final before = cache.revisionFor(_entry(transcript: original));
      final after = cache.revisionFor(_entry(transcript: edited));

      expect(spy.calls, 2, reason: 'length alone must never prove sameness');
      expect(after.transcriptFingerprint, isNot(before.transcriptFingerprint));
    });

    test('a changed revision invalidates even when the text did not', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);

      cache.revisionFor(_entry());
      final after = cache.revisionFor(_entry(transcriptRevision: 'rev-2'));

      expect(spy.calls, 2);
      expect(after.transcriptRevision, 'rev-2');
      expect(cache.hitCount, 0);
    });

    test('changed structural facts invalidate', () {
      for (final variant in <String, ProofSourceEntry>{
        'archived': _entry(archived: true),
        'deleted': _entry(deleted: true),
        'policy': _entry(allowedByArchivePolicy: false),
        'consent': _entry(remoteProcessingConsented: false),
        'sourceType': _entry(sourceType: ProofSourceType.userTyped),
        'createdAt': _entry(createdAt: DateTime.utc(2026, 7, 2)),
      }.entries) {
        final spy = _DigestSpy(_sha256Hex);
        final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);

        cache.revisionFor(_entry());
        cache.revisionFor(variant.value);

        expect(spy.calls, 2, reason: '${variant.key} must invalidate');
        expect(cache.hitCount, 0, reason: '${variant.key} must not hit');
      }
    });

    test('the cached revision reports the facts revalidation reads', () {
      final revision = ProofAdmissionCache().revisionFor(
        _entry(archived: true, allowedByArchivePolicy: false),
      );

      expect(revision.entryId, 'entry-1');
      expect(revision.archiveScope, 'archive-a');
      expect(revision.ownerScope, 'owner-1');
      expect(revision.transcriptRevision, 'rev-1');
      expect(revision.transcriptFingerprint, _sha256Hex(_transcript));
      expect(revision.transcriptLength, _transcript.length);
      expect(revision.archived, isTrue);
      expect(revision.allowedByArchivePolicy, isFalse);
      expect(revision.deleted, isFalse);
      expect(revision.remoteProcessingConsented, isTrue);
      expect(revision.createdAt, _createdAt);
      expect(revision.sourceType, ProofSourceType.userVoiceTranscript);
    });
  });

  group('derived source entries', () {
    ProofSourceEntry build(ProofAdmissionCache cache, {String? transcript}) =>
        cache.sourceEntryFor(
          entryId: 'entry-1',
          archiveScope: 'archive-a',
          ownerScope: 'owner-1',
          transcript: transcript ?? _transcript,
          createdAt: _createdAt,
          sourceType: ProofSourceType.userVoiceTranscript,
        );

    test('an unchanged transcript derives its revision once', () {
      final revisionSpy = _DigestSpy(UserContentSafety.privacyHash);
      final fingerprintSpy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(
        transcriptRevision: revisionSpy.call,
        transcriptFingerprint: fingerprintSpy.call,
      );

      final first = build(cache);
      final second = build(cache);

      expect(revisionSpy.calls, 1);
      expect(fingerprintSpy.calls, 1);
      expect(second.transcriptRevision, first.transcriptRevision);
      expect(
        first.transcriptRevision,
        UserContentSafety.privacyHash(_transcript),
        reason: 'the derived revision must match the capture path scheme',
      );
    });

    test('an edited transcript derives a new revision', () {
      final revisionSpy = _DigestSpy(UserContentSafety.privacyHash);
      final cache = ProofAdmissionCache(transcriptRevision: revisionSpy.call);

      final before = build(cache);
      final after = build(cache, transcript: _editedTranscript);

      expect(revisionSpy.calls, 2);
      expect(after.transcriptRevision, isNot(before.transcriptRevision));
      expect(
        after.transcriptRevision,
        UserContentSafety.privacyHash(_editedTranscript),
      );
    });

    test('the derived entry carries the transcript it was given', () {
      final entry = build(ProofAdmissionCache());

      expect(entry.transcript, _transcript);
      expect(entry.entryId, 'entry-1');
      expect(entry.archiveScope, 'archive-a');
      expect(entry.allowedByArchivePolicy, isTrue);
    });
  });

  group('feature vector cache', () {
    test('a hit avoids recomputation and returns the same vector', () {
      final cache = ProofAdmissionCache();
      var computed = 0;

      ProofFeatureVector read() => cache.featureVector(
        archiveScope: 'archive-a',
        evidenceFingerprint: 'fingerprint-1',
        sourceEntryIds: const {'entry-1'},
        compute: () {
          computed += 1;
          return _vector();
        },
      );

      final first = read();
      final second = read();

      expect(computed, 1);
      expect(second, same(first));
      expect(cache.hitCount, 1);
    });

    test('any changed structural input invalidates', () {
      final variants = <String, Map<String, Object>>{
        'fingerprint': {'evidenceFingerprint': 'fingerprint-2'},
        'archive': {'archiveScope': 'archive-b'},
        'config': {'configVersion': 2},
        'scorer': {'scorerVersion': 2},
        'verifier': {'verifierVersion': 2},
      };

      for (final variant in variants.entries) {
        final cache = ProofAdmissionCache();
        var computed = 0;
        ProofFeatureVector read({
          String archiveScope = 'archive-a',
          String evidenceFingerprint = 'fingerprint-1',
          int configVersion = 1,
          int scorerVersion = 1,
          int verifierVersion = 1,
        }) => cache.featureVector(
          archiveScope: archiveScope,
          evidenceFingerprint: evidenceFingerprint,
          sourceEntryIds: const {'entry-1'},
          configVersion: configVersion,
          scorerVersion: scorerVersion,
          verifierVersion: verifierVersion,
          compute: () {
            computed += 1;
            return _vector();
          },
        );

        read();
        read(
          archiveScope: variant.value['archiveScope'] as String? ?? 'archive-a',
          evidenceFingerprint:
              variant.value['evidenceFingerprint'] as String? ??
              'fingerprint-1',
          configVersion: variant.value['configVersion'] as int? ?? 1,
          scorerVersion: variant.value['scorerVersion'] as int? ?? 1,
          verifierVersion: variant.value['verifierVersion'] as int? ?? 1,
        );

        expect(computed, 2, reason: 'a changed ${variant.key} must recompute');
      }
    });

    test('the cached and uncached paths agree', () {
      final cache = ProofAdmissionCache();
      final uncached = _vector(citationCount: 3);
      final cached = cache.featureVector(
        archiveScope: 'archive-a',
        evidenceFingerprint: 'fingerprint-1',
        sourceEntryIds: const {'entry-1'},
        compute: () => _vector(citationCount: 3),
      );
      final replayed = cache.featureVector(
        archiveScope: 'archive-a',
        evidenceFingerprint: 'fingerprint-1',
        sourceEntryIds: const {'entry-1'},
        compute: () => fail('a hit must not recompute'),
      );

      expect(cached.toJson(), uncached.toJson());
      expect(replayed.toJson(), uncached.toJson());
    });
  });

  group('deterministic invalidation', () {
    test('invalidateEntry drops that entry and the vectors it fed', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      var computedOne = 0;
      var computedTwo = 0;

      void warm() {
        cache
          ..revisionFor(_entry())
          ..revisionFor(_entry(entryId: 'entry-2'))
          ..featureVector(
            archiveScope: 'archive-a',
            evidenceFingerprint: 'fingerprint-1',
            sourceEntryIds: const {'entry-1', 'entry-2'},
            compute: () {
              computedOne += 1;
              return _vector();
            },
          )
          ..featureVector(
            archiveScope: 'archive-a',
            evidenceFingerprint: 'fingerprint-2',
            sourceEntryIds: const {'entry-2'},
            compute: () {
              computedTwo += 1;
              return _vector();
            },
          );
      }

      warm();
      expect(spy.calls, 2);
      cache.invalidateEntry('entry-1');
      warm();

      expect(spy.calls, 3, reason: 'only entry-1 must be rehashed');
      expect(computedOne, 2, reason: 'a vector fed by entry-1 must be dropped');
      expect(computedTwo, 1, reason: 'an unrelated vector must survive');
    });

    test('invalidateArchive drops one archive only', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      var computedA = 0;
      var computedB = 0;

      void warm() {
        cache
          ..revisionFor(_entry())
          ..revisionFor(_entry(archiveScope: 'archive-b'))
          ..featureVector(
            archiveScope: 'archive-a',
            evidenceFingerprint: 'fingerprint-1',
            sourceEntryIds: const {'entry-1'},
            compute: () {
              computedA += 1;
              return _vector();
            },
          )
          ..featureVector(
            archiveScope: 'archive-b',
            evidenceFingerprint: 'fingerprint-1',
            sourceEntryIds: const {'entry-1'},
            compute: () {
              computedB += 1;
              return _vector();
            },
          );
      }

      warm();
      cache.invalidateArchive('archive-a');
      warm();

      expect(spy.calls, 3, reason: 'archive-b must not be rehashed');
      expect(computedA, 2);
      expect(computedB, 1);
    });

    test('invalidateAll empties both caches', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);
      var computed = 0;

      void warm() {
        cache
          ..revisionFor(_entry())
          ..featureVector(
            archiveScope: 'archive-a',
            evidenceFingerprint: 'fingerprint-1',
            sourceEntryIds: const {'entry-1'},
            compute: () {
              computed += 1;
              return _vector();
            },
          );
      }

      warm();
      expect(cache.revisionCount, 1);
      expect(cache.featureVectorCount, 1);

      cache.invalidateAll();
      expect(cache.revisionCount, 0);
      expect(cache.featureVectorCount, 0);

      warm();
      expect(spy.calls, 2);
      expect(computed, 2);
    });

    test('a rebuilt cache reaches the same answers as a warm one', () {
      final warm = ProofAdmissionCache();
      final cold = ProofAdmissionCache();

      final first = warm.revisionFor(_entry());
      warm.invalidateAll();
      final afterInvalidation = warm.revisionFor(_entry());
      final fresh = cold.revisionFor(_entry());

      expect(
        afterInvalidation.transcriptFingerprint,
        first.transcriptFingerprint,
      );
      expect(fresh.transcriptFingerprint, first.transcriptFingerprint);
      expect(fresh.transcriptRevision, first.transcriptRevision);
    });
  });

  group('archive isolation', () {
    test('two archives holding the same entry id never share a revision', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);

      final inA = cache.revisionFor(_entry());
      final inB = cache.revisionFor(_entry(archiveScope: 'archive-b'));

      expect(spy.calls, 2, reason: 'archive-b must not read archive-a');
      expect(cache.hitCount, 0);
      expect(inA.archiveScope, 'archive-a');
      expect(inB.archiveScope, 'archive-b');
      expect(cache.revisionCount, 2);
    });

    test('two owners holding the same entry id never share a revision', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(transcriptFingerprint: spy.call);

      cache.revisionFor(_entry());
      cache.revisionFor(_entry(ownerScope: 'owner-2'));

      expect(spy.calls, 2, reason: 'an account switch must not read across');
      expect(cache.revisionCount, 2);
    });

    test('a derived entry is never served across archives', () {
      final revisionSpy = _DigestSpy(UserContentSafety.privacyHash);
      final cache = ProofAdmissionCache(transcriptRevision: revisionSpy.call);

      ProofSourceEntry build(String archiveScope) => cache.sourceEntryFor(
        entryId: 'entry-1',
        archiveScope: archiveScope,
        ownerScope: 'owner-1',
        transcript: _transcript,
        createdAt: _createdAt,
        sourceType: ProofSourceType.userVoiceTranscript,
      );

      final inA = build('archive-a');
      final inB = build('archive-b');

      expect(revisionSpy.calls, 2);
      expect(inA.archiveScope, 'archive-a');
      expect(inB.archiveScope, 'archive-b');
    });

    test('a feature vector is never served across archives', () {
      final cache = ProofAdmissionCache();
      final seen = <String>[];

      ProofFeatureVector read(String archiveScope) => cache.featureVector(
        archiveScope: archiveScope,
        evidenceFingerprint: 'fingerprint-1',
        sourceEntryIds: const {'entry-1'},
        compute: () {
          seen.add(archiveScope);
          return _vector(citationCount: archiveScope == 'archive-a' ? 1 : 2);
        },
      );

      final inA = read('archive-a');
      final inB = read('archive-b');

      expect(seen, ['archive-a', 'archive-b']);
      expect(inA.citationCount, 1);
      expect(inB.citationCount, 2);
      expect(read('archive-a').citationCount, 1);
    });
  });

  group('bounded size and eviction', () {
    test('the bound is a named constant', () {
      expect(ProofAdmissionCache.maximumCachedEntries, 128);
    });

    test('the revision index never grows past the bound', () {
      final cache = ProofAdmissionCache();

      for (var index = 0; index < 400; index++) {
        cache.revisionFor(_entry(entryId: 'entry-$index'));
      }

      expect(cache.revisionCount, ProofAdmissionCache.maximumCachedEntries);
    });

    test('the feature cache never grows past the bound', () {
      final cache = ProofAdmissionCache();

      for (var index = 0; index < 400; index++) {
        cache.featureVector(
          archiveScope: 'archive-a',
          evidenceFingerprint: 'fingerprint-$index',
          sourceEntryIds: const {'entry-1'},
          compute: _vector,
        );
      }

      expect(
        cache.featureVectorCount,
        ProofAdmissionCache.maximumCachedEntries,
      );
    });

    test('the least recently used revision is the one evicted', () {
      final spy = _DigestSpy(_sha256Hex);
      final cache = ProofAdmissionCache(
        maximumEntries: 2,
        transcriptFingerprint: spy.call,
      );

      cache.revisionFor(_entry());
      cache.revisionFor(_entry(entryId: 'entry-2'));
      expect(spy.calls, 2);

      // entry-1 becomes the most recently used, so entry-2 is next out.
      cache.revisionFor(_entry());
      expect(spy.calls, 2);

      cache.revisionFor(_entry(entryId: 'entry-3'));
      expect(spy.calls, 3);
      expect(cache.revisionCount, 2);

      cache.revisionFor(_entry());
      expect(spy.calls, 3, reason: 'entry-1 was recently used, so it survived');

      cache.revisionFor(_entry(entryId: 'entry-2'));
      expect(spy.calls, 4, reason: 'entry-2 was the least recently used');
    });

    test('the least recently used feature vector is the one evicted', () {
      final cache = ProofAdmissionCache(maximumEntries: 2);
      final computed = <String>[];

      ProofFeatureVector read(String fingerprint) => cache.featureVector(
        archiveScope: 'archive-a',
        evidenceFingerprint: fingerprint,
        sourceEntryIds: const {'entry-1'},
        compute: () {
          computed.add(fingerprint);
          return _vector();
        },
      );

      read('fingerprint-1');
      read('fingerprint-2');
      read('fingerprint-1');
      read('fingerprint-3');
      expect(cache.featureVectorCount, 2);
      expect(computed, ['fingerprint-1', 'fingerprint-2', 'fingerprint-3']);

      read('fingerprint-1');
      expect(computed.length, 3, reason: 'fingerprint-1 must have survived');

      read('fingerprint-2');
      expect(computed, [
        'fingerprint-1',
        'fingerprint-2',
        'fingerprint-3',
        'fingerprint-2',
      ]);
    });

    test('a bound of zero is refused', () {
      expect(
        () => ProofAdmissionCache(maximumEntries: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ProofAdmissionCache(maximumEntries: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('cache keys', () {
    test('no key contains a transcript, a quote or a statement', () {
      final cache = ProofAdmissionCache();
      cache
        ..revisionFor(_entry())
        ..sourceEntryFor(
          entryId: 'entry-2',
          archiveScope: 'archive-a',
          ownerScope: 'owner-1',
          transcript: _editedTranscript,
          createdAt: _createdAt,
          sourceType: ProofSourceType.userTyped,
        )
        ..featureVector(
          archiveScope: 'archive-a',
          evidenceFingerprint: _sha256Hex('$_quote|$_statement'),
          sourceEntryIds: const {'entry-1'},
          compute: _vector,
        );

      final keys = cache.debugCacheKeys;
      expect(keys, hasLength(3));
      for (final key in keys) {
        for (final content in [
          _transcript,
          _editedTranscript,
          _quote,
          _statement,
          'numbers',
          'decided',
          'review',
        ]) {
          expect(key, isNot(contains(content)), reason: key);
        }
        expect(
          key,
          matches(RegExp(r'^[A-Za-z0-9_|\-]+$')),
          reason: 'a key may only be ids, digests and version integers',
        );
      }
    });

    test('the keys are pure functions of their structural inputs', () {
      final first = ProofAdmissionCache.revisionKey(
        archiveScope: 'archive-a',
        ownerScope: 'owner-1',
        entryId: 'entry-1',
      );
      final second = ProofAdmissionCache.revisionKey(
        archiveScope: 'archive-a',
        ownerScope: 'owner-1',
        entryId: 'entry-1',
      );

      expect(second, first);
      expect(
        ProofAdmissionCache.revisionKey(
          archiveScope: 'archive-b',
          ownerScope: 'owner-1',
          entryId: 'entry-1',
        ),
        isNot(first),
      );
      expect(
        ProofAdmissionCache.featureVectorKey(
          archiveScope: 'archive-a',
          evidenceFingerprint: 'fingerprint-1',
          configVersion: 1,
          scorerVersion: 1,
          verifierVersion: 1,
        ),
        ProofAdmissionCache.featureVectorKey(
          archiveScope: 'archive-a',
          evidenceFingerprint: 'fingerprint-1',
          configVersion: 1,
          scorerVersion: 1,
          verifierVersion: 1,
        ),
      );
      expect(
        ProofAdmissionCache.featureVectorKey(
          archiveScope: 'archive-a',
          evidenceFingerprint: 'fingerprint-1',
          configVersion: 2,
          scorerVersion: 1,
          verifierVersion: 1,
        ),
        isNot(
          ProofAdmissionCache.featureVectorKey(
            archiveScope: 'archive-a',
            evidenceFingerprint: 'fingerprint-1',
            configVersion: 1,
            scorerVersion: 1,
            verifierVersion: 1,
          ),
        ),
      );
    });
  });

  group('phase measurement', () {
    setUp(ProofAnalyticsGuard.resetForTest);

    test('a measured phase reports a band, not a timing', () {
      final timings = ProofPipelineTimings();

      final result = timings.measure(ProofPipelinePhase.parse, () => 'parsed');

      expect(result, 'parsed');
      expect(timings.bandFor(ProofPipelinePhase.parse), isNotNull);
      expect(timings.measuredPhases, [ProofPipelinePhase.parse]);
      expect(timings.rawDurationFor(ProofPipelinePhase.parse), isNotNull);
    });

    test('an unmeasured phase reports nothing rather than instant', () {
      final timings = ProofPipelineTimings()
        ..record(ProofPipelinePhase.ranking, const Duration(milliseconds: 10));

      expect(timings.bandFor(ProofPipelinePhase.parse), isNull);
      expect(timings.rawDurationFor(ProofPipelinePhase.parse), isNull);
      expect(timings.bands().keys, [ProofPipelinePhase.ranking]);
    });

    test('a phase measured repeatedly accumulates', () {
      final timings = ProofPipelineTimings()
        ..record(
          ProofPipelinePhase.evidenceVerification,
          const Duration(milliseconds: 30),
        )
        ..record(
          ProofPipelinePhase.evidenceVerification,
          const Duration(milliseconds: 40),
        );

      expect(
        timings.rawDurationFor(ProofPipelinePhase.evidenceVerification),
        const Duration(milliseconds: 70),
      );
      expect(
        timings.bandFor(ProofPipelinePhase.evidenceVerification),
        'under_250ms',
        reason: 'the parts must band as one phase, not as two fast ones',
      );
    });

    test('a phase that threw is still measured', () {
      final timings = ProofPipelineTimings();

      expect(
        () => timings.measure<void>(
          ProofPipelinePhase.structuralValidation,
          () => throw StateError('boom'),
        ),
        throwsStateError,
      );
      expect(
        timings.bandFor(ProofPipelinePhase.structuralValidation),
        isNotNull,
      );
    });

    test('the band boundaries are the shared ones', () {
      final cases = <int, String>{
        0: 'under_50ms',
        49: 'under_50ms',
        50: 'under_250ms',
        249: 'under_250ms',
        250: 'under_1s',
        999: 'under_1s',
        1000: 'under_5s',
        4999: 'under_5s',
        5000: 'over_5s',
        30000: 'over_5s',
      };

      for (final entry in cases.entries) {
        final duration = Duration(milliseconds: entry.key);
        final timings = ProofPipelineTimings()
          ..record(ProofPipelinePhase.ranking, duration);

        expect(
          timings.bandFor(ProofPipelinePhase.ranking),
          entry.value,
          reason: '${entry.key}ms',
        );
        expect(
          timings.bandFor(ProofPipelinePhase.ranking),
          ProofAdmissionAnalytics.durationBand(duration),
          reason: 'the banding must be the existing helper, not a second one',
        );
      }
    });

    test('every phase has an id-shaped token', () {
      expect(ProofPipelinePhase.values.map((phase) => phase.token).toSet(), {
        'parse',
        'structural_validation',
        'evidence_verification',
        'confidence_scoring',
        'ranking',
        'proof_detail_load',
      });
      for (final phase in ProofPipelinePhase.values) {
        expect(phase.token, matches(RegExp(r'^[a-z0-9_]{1,40}$')));
      }
    });

    test('analytics payloads carry bands only and survive the guard', () {
      final timings = ProofPipelineTimings()
        ..record(ProofPipelinePhase.parse, const Duration(milliseconds: 5))
        ..record(
          ProofPipelinePhase.proofDetailLoad,
          const Duration(seconds: 2),
        );

      final payloads = timings.analyticsPayloads();

      expect(payloads, [
        {'stage': 'parse', 'duration_band': 'under_50ms'},
        {'stage': 'proof_detail_load', 'duration_band': 'under_5s'},
      ]);
      for (final payload in payloads) {
        for (final value in payload.values) {
          expect(
            value,
            isA<String>(),
            reason: 'a raw millisecond figure must never be emitted',
          );
        }
        expect(
          ProofAnalyticsGuard.sanitize(ProofPipelineTimings.eventName, payload),
          payload,
        );
      }
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('no payload can contain a millisecond figure', () {
      final timings = ProofPipelineTimings()
        ..record(ProofPipelinePhase.ranking, const Duration(milliseconds: 137));

      final serialised = timings.analyticsPayloads().toString();

      expect(serialised, isNot(contains('137')));
      expect(serialised, contains('under_250ms'));
    });

    test('a negative duration is refused', () {
      expect(
        () => ProofPipelineTimings().record(
          ProofPipelinePhase.parse,
          const Duration(milliseconds: -1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('reset clears the run', () {
      final timings = ProofPipelineTimings()
        ..record(ProofPipelinePhase.parse, const Duration(milliseconds: 5))
        ..reset();

      expect(timings.measuredPhases, isEmpty);
      expect(timings.analyticsPayloads(), isEmpty);
    });

    test('a cache carries its own timings', () {
      final cache = ProofAdmissionCache();

      cache.timings.measure(ProofPipelinePhase.ranking, () {});

      expect(cache.timings.bandFor(ProofPipelinePhase.ranking), isNotNull);
    });
  });
}