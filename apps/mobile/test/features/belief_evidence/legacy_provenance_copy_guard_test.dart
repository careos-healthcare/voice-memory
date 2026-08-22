import 'dart:io';

import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the on-device switch's own label.
///
/// The real label is `OnDeviceProcessingCopy.title` and it contains an
/// absolute of its own. Quoting a control's name back to a user so they can
/// find the row is not this file making that claim, so the templates are
/// checked with a neutral name and the substitution is left to the caller.
const _settingName = 'Keep processing on this device';

/// Words that promise more than any build can keep.
const _absolutes = <String>[
  '100%',
  '100 percent',
  'zero',
  'entirely',
  'completely',
  'totally',
  'absolutely',
  'always',
  'never',
  'nothing',
  'none of',
  'only ever',
  'guarantee',
  'every single',
  'all of your',
  'at all times',
];

/// Words that would tell a user their recording or their words are gone.
///
/// This is the failure mode the whole treatment exists to avoid. The entry is
/// intact; what is unknown is where its text came from. Copy that reaches for
/// any of these turns a withheld attribution into a bereavement.
const _lossWords = <String>[
  'lost',
  'lose',
  'losing',
  'deleted',
  'erased',
  'wiped',
  'destroyed',
  'corrupt',
  'damaged',
  'unrecoverable',
  'gone forever',
  'no longer have',
  'discarded',
  'thrown away',
];

/// Words that would make a normal state sound like a fault, or make the user
/// feel responsible for one.
const _alarmOrBlameWords = <String>[
  'error',
  'failure',
  'failed',
  'invalid',
  'corrupted',
  'warning',
  'unfortunately',
  'sorry',
  'you should have',
  'your mistake',
  'you forgot',
  'you must',
  'problem',
  'broken',
];

/// Every user-visible string this feature can render, templates filled in.
List<String> _allCopy() => [
  ...LegacyProvenanceCopy.all,
  LegacyProvenanceCopy.semantics(recovery: ''),
  ...ProvenanceRecoveryCopy.all,
  ProvenanceRecoveryCopy.scopeFor(1),
  ProvenanceRecoveryCopy.scopeFor(12),
  ProvenanceRecoveryCopy.partialScopeFor(withAudio: 3, total: 12),
  ProvenanceRecoveryCopy.onDeviceOnlyBlocker(_settingName),
  ProvenanceRecoveryCopy.bothBlockers(_settingName),
  ProvenanceRecoveryCopy.outcomeRecovered(recovered: 1, requested: 1),
  ProvenanceRecoveryCopy.outcomeRecovered(recovered: 3, requested: 12),
  ProvenanceRecoveryCopy.actionSemantics(1),
  ProvenanceRecoveryCopy.actionSemantics(12),
];

void main() {
  group('no absolutes', () {
    test('no string claims more than the app can know', () {
      for (final line in _allCopy()) {
        final lower = line.toLowerCase();
        for (final absolute in _absolutes) {
          expect(
            lower.contains(absolute),
            isFalse,
            reason: 'absolute "$absolute" in: $line',
          );
        }
      }
    });
  });

  group('no implied data loss', () {
    test('no string suggests the recording or the text went away', () {
      for (final line in _allCopy()) {
        final lower = line.toLowerCase();
        for (final word in _lossWords) {
          expect(
            lower.contains(word),
            isFalse,
            reason: 'loss wording "$word" in: $line',
          );
        }
      }
    });

    test('the notice states outright that the entry is still there', () {
      expect(LegacyProvenanceCopy.body, contains('still saved'));
    });

    test('a finished check that found nothing leaves the entry untouched', () {
      expect(ProvenanceRecoveryCopy.outcomeNoneRecovered, contains('untouched'));
    });
  });

  group('quiet, not alarming, and not the user\u2019s fault', () {
    test('no alarm or blame vocabulary', () {
      for (final line in _allCopy()) {
        final lower = line.toLowerCase();
        for (final word in _alarmOrBlameWords) {
          expect(
            lower.contains(word),
            isFalse,
            reason: 'alarm/blame wording "$word" in: $line',
          );
        }
      }
    });

    test('the notice tells the reader there is nothing for them to fix', () {
      expect(
        LegacyProvenanceCopy.helper.toLowerCase(),
        contains('do not need to do anything'),
      );
    });
  });

  group('honest about what is unknown', () {
    test('the body claims inability to confirm, not knowledge of fakery', () {
      final lower = LegacyProvenanceCopy.body.toLowerCase();
      expect(lower, contains('cannot confirm'));
      // The opposite claim — that the text *is* generated — is not supported
      // by anything on disk and must not appear.
      expect(lower, isNot(contains('was written by the app')));
      expect(lower, isNot(contains('is not your words')));
    });

    test('the cause is named as an old build, not as a defect', () {
      expect(
        LegacyProvenanceCopy.body.toLowerCase(),
        contains('saved before the app kept a record'),
      );
    });
  });

  group('the recover action survives the mechanism changing', () {
    test('the label describes the goal, not the transport', () {
      final label = ProvenanceRecoveryCopy.actionLabel.toLowerCase();
      for (final transport in ['upload', 'send', 'server', 'cloud']) {
        expect(
          label.contains(transport),
          isFalse,
          reason: 'transport word "$transport" in the action label',
        );
      }
    });

    test('the receiver is named where the transport is described', () {
      expect(
        ProvenanceRecoveryCopy.remoteDisclosure,
        contains('OpenAI Whisper'),
      );
      expect(
        ProvenanceRecoveryCopy.remoteDisclosure.toLowerCase(),
        contains('server'),
      );
    });
  });

  group('the shipped privacy gate', () {
    test('every string clears PrivacyCopyPolicy on its own', () {
      for (final line in _allCopy()) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(line),
          isEmpty,
          reason: 'privacy policy violation in: $line',
        );
      }
    });
  });

  group('copy lives in the copy file', () {
    const widgetSources = [
      'lib/features/belief_evidence/ui/legacy_provenance_notice.dart',
      'lib/features/belief_evidence/ui/provenance_recovery_action.dart',
    ];

    test('no widget file carries a prose literal of its own', () {
      final literal = RegExp(r"'([^'\\]*)'");
      for (final path in widgetSources) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('import ') ||
              trimmed.startsWith('//') ||
              trimmed.startsWith('///')) {
            continue;
          }
          for (final match in literal.allMatches(line)) {
            final value = match.group(1)!;
            // Keys and identifiers are single tokens; prose has spaces.
            expect(
              value.contains(' '),
              isFalse,
              reason: 'inline copy in $path:${i + 1}: "$value"',
            );
          }
        }
      }
    });
  });
}
