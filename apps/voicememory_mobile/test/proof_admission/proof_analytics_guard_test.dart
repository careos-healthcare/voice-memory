import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/proof_analytics_guard.dart';

/// Returns the drop record for [key], or null when [key] was not refused.
AnalyticsGuardDrop? dropFor(String key) {
  for (final drop in ProofAnalyticsGuard.drops) {
    if (drop.key == key) return drop;
  }
  return null;
}

void main() {
  setUp(ProofAnalyticsGuard.resetForTest);

  group('hostile payloads', () {
    test('strips a transcript and records the drop', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'transcript': 'I said yes again at work',
      });

      expect(safe, isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 1);
      final drop = dropFor('transcript');
      expect(drop, isNotNull);
      expect(drop!.reason, AnalyticsDropReason.forbiddenKey);
      expect(drop.event, 'proof_admitted');
      // The refused value itself is never retained.
      expect(drop.toString(), isNot(contains('yes again at work')));
    });

    test(
      'strips the four real leaks: prompt, theme, topic_label, entry_id',
      () {
        final safe = ProofAnalyticsGuard.sanitize('mixed_event', {
          'prompt': 'why do I keep saying yes?',
          'theme': 'work boundaries',
          'topic_label': 'saying yes at work',
          'entry_id': 'a1b2c3d4e5',
          'source': 'post_save',
        });

        expect(safe, {'source': 'post_save'});
        expect(dropFor('prompt')!.reason, AnalyticsDropReason.forbiddenKey);
        expect(dropFor('theme')!.reason, AnalyticsDropReason.forbiddenKey);
        expect(
          dropFor('topic_label')!.reason,
          AnalyticsDropReason.forbiddenPattern,
        );
        expect(dropFor('entry_id')!.reason, AnalyticsDropReason.forbiddenKey);
        expect(ProofAnalyticsGuard.droppedCount, 4);
      },
    );

    test('strips camelCase variants of forbidden keys', () {
      final safe = ProofAnalyticsGuard.sanitize('mixed_event', {
        'topicLabel': 'saying yes at work',
        'entryId': 'a1b2c3d4e5',
        'archiveId': 'arch_1',
        'proofId': 'proof_1',
      });

      expect(safe, isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 4);
    });

    test('strips quote, conclusion and correction-note values', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_reviewed', {
        'quote': 'I said yes again',
        'conclusion': 'you avoid conflict',
        'correction_note': 'that was not what I meant',
        'observation': 'user hesitated',
        'interpretation': 'avoidance',
        'wording': 'softened',
      });

      expect(safe, isEmpty);
      expect(dropFor('quote')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(dropFor('conclusion')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(
        dropFor('correction_note')!.reason,
        AnalyticsDropReason.forbiddenPattern,
      );
      expect(ProofAnalyticsGuard.droppedCount, 6);
    });

    test('strips a fingerprint and a raw score', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_scored', {
        'fingerprint': 'ab12cd34ef56',
        'score': 0.8123,
        'raw_score': 0.8123,
        'confidence_band': 'medium',
      });

      expect(safe, {'confidence_band': 'medium'});
      expect(dropFor('fingerprint')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(dropFor('score')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(dropFor('raw_score')!.reason, AnalyticsDropReason.forbiddenKey);
    });

    test('strips a provider error string, stacktrace and file path', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_failed', {
        'error_message': 'PlatformException: transcript upload failed',
        'stacktrace': '#0 ProofAdmission.admit (package:app/proof.dart:42)',
        'stack_trace': '#0 ProofAdmission.admit',
        'path': '/var/mobile/Containers/entry_42.m4a',
        'filename': 'entry_42.m4a',
        'reason': 'provider_unavailable',
      });

      expect(safe, {'reason': 'provider_unavailable'});
      expect(
        dropFor('error_message')!.reason,
        AnalyticsDropReason.forbiddenKey,
      );
      expect(dropFor('stacktrace')!.reason, AnalyticsDropReason.forbiddenKey);
      // `stack_trace` normalises onto the same exact rule as `stacktrace`.
      expect(dropFor('stack_trace')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(dropFor('path')!.reason, AnalyticsDropReason.forbiddenKey);
      expect(dropFor('filename')!.reason, AnalyticsDropReason.forbiddenKey);
    });

    test('strips secrets, tokens and keys', () {
      final safe = ProofAnalyticsGuard.sanitize('auth_event', {
        'token': 'eyJhbGciOi',
        'api_key': 'sk_live_123',
        'key': 'k1',
        'secret': 's1',
        'refresh_token': 'rt_1',
      });

      expect(safe, isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 5);
    });

    test('unknown keys are refused by default', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'freshly_invented_key': 'ok_value',
      });

      expect(safe, isEmpty);
      expect(
        dropFor('freshly_invented_key')!.reason,
        AnalyticsDropReason.notAllowlisted,
      );
    });
  });

  group('legitimate structural payloads', () {
    test('a full structural payload survives intact', () {
      const payload = <String, Object>{
        'source': 'post_save',
        'entry_count': 3,
        'card_type': 'proof',
        'confidence_band': 'medium',
        'admission_result': 'admitted',
      };

      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', payload);

      expect(safe, payload);
      expect(ProofAnalyticsGuard.droppedCount, 0);
      expect(ProofAnalyticsGuard.drops, isEmpty);
    });

    test('near-miss keys card_type and entry_count survive', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'card_type': 'proof',
        'entry_count': 12,
      });

      expect(safe, {'card_type': 'proof', 'entry_count': 12});
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('near-miss band and version keys survive', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'score_band': 'high',
        'scorer_version': 'v3',
        'verifier_version': 'v2',
        'migration_version': 4,
        'prompt_type': 'reflection',
        'error_type': 'timeout',
        'reason_id': 'low_sources',
        'line_id': 'l7',
      });

      expect(safe.keys, hasLength(8));
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('remaining proof-admission structural keys survive', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'rejection_reason': 'insufficient_sources',
        'source_count_band': 'two_to_three',
        'contradiction_count_band': 'none',
        'correction_choice': 'keep_exact_details',
        'duration_band': 'under_1s',
      });

      expect(safe.keys, hasLength(5));
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('bools and numbers survive', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'enabled': true,
        'has_snippets': false,
        'entry_count': 0,
        'milestone_count': 2,
      });

      expect(safe, {
        'enabled': true,
        'has_snippets': false,
        'entry_count': 0,
        'milestone_count': 2,
      });
    });
  });

  group('value-shape gate', () {
    test('free text under an allowlisted key is still rejected', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'reason': 'I said yes again at work and felt awful',
        'source': 'post_save',
      });

      expect(safe, {'source': 'post_save'});
      expect(dropFor('reason')!.reason, AnalyticsDropReason.valueShape);
    });

    test('capitals, punctuation and over-long values are rejected', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'stage': 'Admitted',
        'answer': 'yes, definitely',
        'plan': 'a' * 41,
        'status': 'ok',
      });

      expect(safe, {'status': 'ok'});
      expect(dropFor('stage')!.reason, AnalyticsDropReason.valueShape);
      expect(dropFor('answer')!.reason, AnalyticsDropReason.valueShape);
      expect(dropFor('plan')!.reason, AnalyticsDropReason.valueShape);
    });

    test('a 40 character id-shaped value is the boundary that survives', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'plan': 'a' * 40,
      });

      expect(safe, {'plan': 'a' * 40});
    });

    test('non-primitive values are rejected without stringification', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'source': ['post_save', 'I said yes again'],
        'reason': {'text': 'I said yes again'},
      });

      expect(safe, isEmpty);
      expect(dropFor('source')!.reason, AnalyticsDropReason.valueType);
      expect(dropFor('reason')!.reason, AnalyticsDropReason.valueType);
      for (final drop in ProofAnalyticsGuard.drops) {
        expect(drop.toString(), isNot(contains('I said yes again')));
      }
    });

    test('NaN and infinite numbers are rejected', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        'entry_count': double.nan,
        'milestone_count': double.infinity,
      });

      expect(safe, isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 2);
    });
  });

  group('fail-closed behaviour', () {
    test('null and empty payloads are safe', () {
      expect(ProofAnalyticsGuard.sanitize('e', null), isEmpty);
      expect(ProofAnalyticsGuard.sanitize('e', const {}), isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 0);
    });

    test('an empty or symbol-only key is refused', () {
      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', {
        '': 'x',
        '!!!': 'x',
      });

      expect(safe, isEmpty);
      expect(ProofAnalyticsGuard.droppedCount, 2);
    });

    test('never throws on a hostile mixed payload', () {
      expect(
        () => ProofAnalyticsGuard.sanitize('proof_admitted', {
          'transcript': 'text',
          'entry_count': 1,
          'weird': Object(),
        }),
        returnsNormally,
      );
    });

    test('attributes beyond the cap are dropped, not emitted', () {
      final payload = <String, Object>{};
      for (var i = 0; i < ProofAnalyticsGuard.maxAttributes + 5; i++) {
        payload['k$i'] = i;
      }
      payload.addAll({
        for (final key in ProofAnalyticsGuard.allowedKeys.take(30)) key: 1,
      });

      final safe = ProofAnalyticsGuard.sanitize('proof_admitted', payload);

      expect(safe.length, lessThanOrEqualTo(ProofAnalyticsGuard.maxAttributes));
      expect(
        ProofAnalyticsGuard.drops.any(
          (d) => d.reason == AnalyticsDropReason.payloadCap,
        ),
        isTrue,
      );
    });

    test('no allowlisted key matches a forbidden rule without exemption', () {
      for (final key in ProofAnalyticsGuard.allowedKeys) {
        final safe = ProofAnalyticsGuard.sanitize('audit', {key: 'ok_value'});
        expect(
          safe.containsKey(key),
          isTrue,
          reason: '$key is allowlisted but was refused by a forbidden rule',
        );
      }
    });
  });
}
