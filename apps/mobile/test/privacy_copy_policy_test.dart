import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// The CI gate and this test share one implementation of the walk, so they
// cannot disagree about what "covered" means. `show` keeps the script's main()
// out of this library.
import '../tool/privacy/check_privacy_copy_policy.dart'
    show
        discoverPrivacyCopySources,
        newPrivacyCopyViolations,
        privacyCopyBaselinePath,
        readPrivacyCopyBaseline,
        stalePrivacyCopyBaselineEntries,
        uncoveredRequiredSources;

void main() {
  group('PrivacyCopyPolicy constants', () {
    test('allowed promises match the canonical wording', () {
      expect(PrivacyCopyPolicy.privateByDefault, 'Private by default');
      expect(
        PrivacyCopyPolicy.nothingSentUnlessChosen,
        'Nothing is sent unless you choose cloud, sync, or transcription.',
      );
      expect(
        PrivacyCopyPolicy.exportDeleteAnytime,
        'You can export or delete your local archive at any time.',
      );
      expect(PrivacyCopyPolicy.lockArchiveMe, 'Protect this archive');
    });
  });

  group('PrivacyCopyPolicy literal guards', () {
    test('flags never sent without unless you choose', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral('Your data is never sent'),
        isNotEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          PrivacyCopyPolicy.nothingSentUnlessChosen,
        ),
        isEmpty,
      );
    });

    test('flags unsafe security superlatives', () {
      for (final bad in const [
        '100% secure',
        'military grade encryption',
        'military-grade protection',
        'unhackable vault',
        'unbreakable privacy',
        'impossible to access without permission',
        'nothing ever leaves your device',
        'delete from every server instantly',
        'all journal data is encrypted',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(bad),
          isNotEmpty,
          reason: 'should reject "$bad"',
        );
      }
    });

    test('a negated or contrastive banned word is not a claim', () {
      for (final allowed in const [
        'No medical claims',
        'No treatment-style framing',
        'No therapist-ready claims',
        'This is not a diagnosis.',
        'This is not advice or a diagnosis.',
        'Not for diagnosis or emergency use',
        'It is not a therapy or medical service.',
        'Pro does not make medical, therapy, or diagnostic claims.',
        'Do not make vague AI claims',
        "This isn't therapy.",
        'Never say more AI',
        'Compare against Chat AI',
        'An evidence trail, not voice chat or more AI.',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(allowed),
          isEmpty,
          reason: 'should allow "$allowed"',
        );
      }
    });

    test('negation does not excuse a claim in the next clause', () {
      for (final flagged in const [
        // The cue is spent by the sentence boundary.
        'This is not advice. Diagnosis follows.',
        // No cue at all — the phrases Task 1 removed must stay detectable.
        'AI processing happens entirely on this device',
        'AI processing happens locally on this device',
        'ArchiveMe replaces therapy',
        'Get a diagnosis from your archive',
        // Far enough back that the cue no longer governs.
        'We do not sell your data, and every reflection you read here is '
            'a medical opinion',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(flagged),
          isNotEmpty,
          reason: 'should reject "$flagged"',
        );
      }
    });

    test('flags anonymous unless explicitly supported', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral('Your archive is anonymous'),
        isNotEmpty,
      );
    });

    test('allows encrypted backup and sync copy only in supported contexts', () {
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'If you sign in and enable sync, backup data is encrypted before it is stored.',
        ),
        isEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Sign in with email to encrypt a backup of what you built on this device.',
        ),
        isEmpty,
      );
      expect(
        PrivacyCopyPolicy.violationsInLiteral(
          'Your entries are encrypted on this device.',
        ),
        isNotEmpty,
      );
    });
  });

  group('Machine identifier literals', () {
    test('widget and preference keys are not read as promises', () {
      for (final token in const [
        'encryption_status_card',
        'pillar_3_encryption',
        'sqlite_encryption_key_v2',
        'notForDiagnosisAcknowledged',
        '.encrypted-temp',
      ]) {
        expect(
          PrivacyCopyPolicy.isMachineIdentifierLiteral(token),
          isTrue,
          reason: token,
        );
      }
    });

    test('words a user reads are still scanned', () {
      for (final copy in const [
        'Diagnosis',
        'unhackable',
        'military-grade',
        'Encrypted at Rest',
      ]) {
        expect(
          PrivacyCopyPolicy.isMachineIdentifierLiteral(copy),
          isFalse,
          reason: copy,
        );
      }
    });
  });

  group('Banned vocabulary declarations', () {
    test('a guard list of forbidden words is not read as a promise', () {
      const source = '''
abstract class Guard {
  static const List<String> bannedTerms = [
    'therapy',
    'diagnosis',
    'anonymous',
  ];

  static const String tagline = 'Your archive is anonymous.';
}
''';

      final violations = PrivacyCopyPolicy.scanFile(
        'lib/features/guard/guard_copy.dart',
        source,
      );

      // Only the tagline offends; the list entries are prohibitions, and
      // scanning must resume after the list closes.
      expect(violations, hasLength(1));
      expect(violations.single, contains('Your archive is anonymous.'));
    });
  });

  group('Consumer privacy copy discovery', () {
    test('a new copy file cannot land outside the scan', () {
      for (final covered in const [
        'lib/features/anything/anything_copy.dart',
        'lib/features/settings/ui/on_device_architecture_copy.dart',
        'lib/features/onboarding/ui/remote_processing_consent_step.dart',
        'lib/screens/privacy_screen.dart',
        'lib/widgets/security/archive_data_flow_sheet.dart',
      ]) {
        expect(
          PrivacyCopyPolicy.isConsumerPrivacySource(covered),
          isTrue,
          reason: covered,
        );
      }

      for (final ignored in const [
        'lib/models/journal_entry.dart',
        'lib/storage/journal_store.dart',
        // The policy declares the banned vocabulary; scanning it would only
        // ever report its own rule table.
        PrivacyCopyPolicy.policySelfPath,
      ]) {
        expect(
          PrivacyCopyPolicy.isConsumerPrivacySource(ignored),
          isFalse,
          reason: ignored,
        );
      }
    });

    test('explicitly required sources exist and are discovered', () {
      final uncovered = uncoveredRequiredSources();
      expect(
        uncovered,
        isEmpty,
        reason:
            'PrivacyCopyPolicy.consumerPrivacySources is stale — these are '
            'missing or no longer matched: ${uncovered.join(', ')}',
      );
      final discovered = discoverPrivacyCopySources().keys;
      for (final path in PrivacyCopyPolicy.consumerPrivacySources) {
        expect(discovered, contains(path), reason: 'not scanned: $path');
      }
    });
  });

  group('Consumer privacy copy scan', () {
    late Map<String, String> sources;
    late List<String> violations;
    late Set<String> baseline;

    setUpAll(() {
      sources = discoverPrivacyCopySources();
      violations = PrivacyCopyPolicy.scanSources(sources)..sort();
      baseline = readPrivacyCopyBaseline();
    });

    test('scans a meaningful number of sources', () {
      expect(sources.length, greaterThan(100));
    });

    test('no unsafe privacy promise outside the baseline', () {
      final unbaselined = newPrivacyCopyViolations(violations, baseline);
      expect(
        unbaselined,
        isEmpty,
        reason:
            'New privacy copy violations:\n${unbaselined.join('\n')}\n'
            'Fix the copy — do not append to $privacyCopyBaselinePath.',
      );
    });

    test('baseline holds no entry that was already fixed', () {
      final stale = stalePrivacyCopyBaselineEntries(violations, baseline);
      expect(
        stale,
        isEmpty,
        reason:
            'These were fixed, so delete them from $privacyCopyBaselinePath '
            'to keep the burn-down honest:\n${stale.join('\n')}',
      );
    });

    test('surfaces owned by the local-first statement stay clean', () {
      for (final path in const [
        'lib/features/settings/ui/on_device_architecture_copy.dart',
        'lib/features/settings/ui/on_device_architecture_section.dart',
        'lib/features/onboarding/ui/remote_processing_consent_copy.dart',
        'lib/features/onboarding/ui/remote_processing_consent_step.dart',
        'lib/ui/screens/settings/privacy_security_screen.dart',
      ]) {
        final source = sources[path];
        expect(source, isNotNull, reason: 'not discovered: $path');
        final violations = PrivacyCopyPolicy.scanFile(path, source!);
        expect(violations, isEmpty, reason: violations.join('\n'));
      }
    });
  });
}
