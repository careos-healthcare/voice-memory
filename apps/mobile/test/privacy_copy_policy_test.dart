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
        PrivacyCopyPolicy.nothingSentUnlessFeatureChosen,
        'Nothing is sent unless you choose a feature that needs it.',
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
          PrivacyCopyPolicy.nothingSentUnlessFeatureChosen,
        ),
        isEmpty,
      );
    });

    group('absolute and quantified privacy claims', () {
      test('rejects the two claims the narrow trigger let through', () {
        // Both cleared the old `never sent|never leaves|nothing ever leaves`
        // pattern, which is how they reached review.
        for (final claim in const [
          'All AI processing happens 100% on your device hardware',
          'zero data is ever sent to OpenAI, Anthropic, or external cloud '
              'servers.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(claim),
            isTrue,
            reason: claim,
          );
        }
      });

      test('rejects absolute claims however they are worded', () {
        for (final claim in const [
          'Your recordings are never uploaded.',
          'Nothing is shared with anyone, at all times.',
          'Your archive is stored entirely on this device.',
          'No one can read your transcripts.',
          'We guarantee your audio stays offline.',
          'Your entries are processed exclusively on-device.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(claim),
            isTrue,
            reason: claim,
          );
        }
      });

      test('a claim that names its condition is the safe form', () {
        for (final scoped in const [
          'Nothing is sent unless you choose a feature that needs it.',
          'Nothing is sent for transcription or reflection until you turn '
              'this on.',
          'When remote processing is off, nothing is sent for new moments.',
          'Revoke access any time — nothing is shared without your say.',
          'Off is where you start, and where you can return: nothing is sent '
              'for new moments, and the switch lives in Settings → Privacy.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(scoped),
            isFalse,
            reason: scoped,
          );
        }
      });

      test('a claim bounded to its own surface is not an overclaim', () {
        // These are true where they are written: screens that make no network
        // call, and cards whose contents are fixed. They are the same shape as
        // the two claims above, which is why the first version of the rule
        // reported all of them. What separates them is that none names a
        // subject ranging over the product — content, somewhere off this
        // device, or another reader — paired with an act the product performs.
        // Adding "unless you choose" to any of them would make it less true.
        for (final bounded in const [
          'Nothing is uploaded.',
          'Nothing is uploaded from this screen.',
          'Local counters for this device only. Nothing is sent '
              'automatically.',
          'Share safely never includes your private notes.',
          'Coach access is logged locally. Raw transcripts are never '
              'exported.',
          'Open Sample Archive for example data that never writes to your '
              'journal.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(bounded),
            isFalse,
            reason: bounded,
          );
        }
      });

      test('naming a destination still reports the same sentence', () {
        // The narrowing above must not be reachable by adding a destination:
        // the moment a bounded claim says where content does not go, it is an
        // app-wide promise again.
        for (final wide in const [
          'Nothing is uploaded to our servers.',
          'Nothing is ever sent to the cloud.',
          'No one can read your transcripts.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(wide),
            isTrue,
            reason: wide,
          );
        }
      });

      test('counts, empty states, and prohibitions are not claims', () {
        for (final allowed in const [
          'Nothing saved yet. Save one real moment first.',
          'Nothing to export yet',
          'First-use onboarding visible at zero entries',
          'This is not quoted, because nothing in your saved entries matches '
              'it.',
          'Never say more AI, life-dashboard framing, or storage framing.',
          'No never-lose-your-archive promise before sync is proven.',
          'Treat them as intent rather than a guarantee.',
          'Over time it may show cautious, evidence-backed changes — always '
              'with your own words cited behind them.',
        ]) {
          expect(
            PrivacyCopyPolicy.isUnscopedAbsoluteClaim(allowed),
            isFalse,
            reason: allowed,
          );
        }
      });

      test('an approved absolute claim is approved by its exact wording', () {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(
            PrivacyCopyPolicy.encryptionBaselineDetail,
          ),
          isEmpty,
        );
        expect(
          PrivacyCopyPolicy.isUnscopedAbsoluteClaim(
            'Keys are never transmitted anywhere.',
          ),
          isTrue,
          reason: 'a reworded variant must not inherit the approval',
        );
      });
    });

    test('a sentence split across source lines is scanned whole', () {
      // The scope cue sits on the second line. Read a line at a time, the
      // first half is an unconditional "Nothing is sent".
      const source = '''
abstract class Copy {
  static const String off =
      'Off — new moments are saved on this device only. Nothing is sent '
      'for transcription or reflection until you turn this on.';
}
''';
      expect(
        PrivacyCopyPolicy.scanFile('lib/features/x/x_copy.dart', source),
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

    test('a custody verb near an encryption word clears accurate copy', () {
      // Each of these failed only for its word order. The evidence, in the same
      // order: the outbox drains `SyncBlobPushDto.encrypted`, an
      // `EncryptedPayloadDto`; `EncryptedSqliteVaultSyncPipeline.uploadVault`
      // seals the SQLite bytes with AES-256-GCM before the iCloud transport
      // sees them; `JournalStore` is `encrypted_json_file` / `encrypted: true`
      // in `PrivateStorageAudit.knownStores()`.
      for (final accurate in const [
        'Uploading encrypted changes…',
        'Backing up encrypted vault…',
        '[draft] entries in encrypted journal + localAudioPath (audio plaintext)',
        'ArchiveMe stores your journal file encrypted on this device. Archive '
            'metadata and prefs remain in plaintext JSON. Share cards do not '
            'include your raw entries.',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(accurate),
          isEmpty,
          reason: 'accurate encryption copy should clear: "$accurate"',
        );
      }
    });

    test('widening for custody verbs does not license plaintext audio claims', () {
      // The load-bearing test for the widening above. "Uploading your encrypted
      // audio" is the same sentence shape as "Uploading encrypted changes…" and
      // matches the same custody-verb rule; the only thing separating them is
      // that `PrivateStorageAudit.knownStores()` records `VoiceRecordings` as
      // `temp_file` / `encrypted: false`. This was live first-run copy on
      // `BrainDumpCopy.generatingBody`. If this test ever goes green by the
      // allowlist widening rather than the plaintext veto, the gate has been
      // taught to approve the exact claim it was added to catch.
      for (final falseClaim in const [
        'Uploading your encrypted audio and finding patterns in what you shared.',
        'Uploading your encrypted audio',
        'Backing up encrypted recordings…',
        'Your recordings are encrypted on this device.',
        'We store your encrypted voice notes here.',
        'Syncing encrypted audio',
      ]) {
        expect(
          PrivacyCopyPolicy.violationsInLiteral(falseClaim),
          isNotEmpty,
          reason:
              'recorded audio is plaintext m4a under system temp — this must '
              'still report: "$falseClaim"',
        );
      }
    });

    test('the plaintext-audio veto cannot be overridden by an allowed context', () {
      // Both halves of the veto's contract: a claim that pairs recorded audio
      // with encryption reports even when it also matches an approved context,
      // and the reason names the audit rather than the missing context, so the
      // failure explains which store contradicts it.
      final violations = PrivacyCopyPolicy.violationsInLiteral(
        'Your encrypted audio is included in the encrypted backup.',
      );
      expect(violations, isNotEmpty);
      expect(
        violations.any((v) => v.contains('PrivateStorageAudit')),
        isTrue,
        reason: 'the veto, not the missing-context rule, should fire',
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
