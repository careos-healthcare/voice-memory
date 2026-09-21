import 'package:archiveme_mobile/security/privacy_claim_catalogue.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// Same discovery walk the CI gate uses, so the gate and this test cannot
// disagree about which files count as privacy copy.
import '../../tool/privacy/check_privacy_copy_policy.dart'
    show discoverPrivacyCopySources, isRetiredSprawlPath;
import '../../tool/privacy/copy_declarations.dart';

/// Two structural gates over the privacy copy surface.
///
/// Gate 2 — byte-identical constant declarations. Two literals that spell the
/// same sentence are two places a correction has to land, and the `/privacy`
/// screen is the record of what happens when only one gets it. Aliases and
/// compositions are exempt on purpose: that makes reusing a claim the cheap
/// path and retyping it the failing one.
///
/// Gate 3 — claim-level contradiction. An encryption claim that names a
/// database without naming both platforms it holds on, and any copy that
/// pairs a remote word with an automatic one. Both rules live in
/// [PrivacyCopyPolicy] so they apply to every source, not one screen.
void main() {
  late Map<String, String> sources;
  late List<CopyDeclaration> declarations;

  setUpAll(() {
    sources = discoverPrivacyCopySources();
    declarations = [
      for (final entry in sources.entries)
        ...parseCopyDeclarations(entry.key, entry.value),
    ];
  });

  /// Retired sprawl is compiled and shipped but excluded from the analyzer and
  /// carries the bulk of the pre-existing debt. The gates run over live `lib/`
  /// so a new duplicate cannot land; retired duplicates are reported by
  /// `tool/privacy/check_privacy_copy_policy.dart`.
  bool isLive(String path) => !isRetiredSprawlPath('$path: x');

  // Real duplications in files this change was not allowed to edit. Listed
  // rather than silently filtered, so the debt is visible and the entry is
  // deleted the moment the owning change lands.
  //
  // "Caregiver & coach access": screenTitle and settingsTitle in
  // lib/features/auth/domain/caregiver_access_copy.dart. Owned by the
  // caregiver-consent work in flight.
  const deferredToOtherOwners = {'Caregiver & coach access'};

  group('gate: byte-identical constant declarations', () {
    test('discovery finds a meaningful number of declarations', () {
      expect(declarations, hasLength(greaterThan(500)));
      expect(
        declarations.where((d) => d.kind == CopyDeclarationKind.alias),
        isNotEmpty,
      );
      expect(
        declarations.where((d) => d.kind == CopyDeclarationKind.composition),
        isNotEmpty,
      );
    });

    test('no claim is spelled out twice in live copy', () {
      final byValue = <String, List<CopyDeclaration>>{};
      for (final declaration in declarations) {
        if (declaration.kind != CopyDeclarationKind.literal) continue;
        if (!isLive(declaration.path)) continue;
        final value = declaration.literalValue!.trim();
        if (value.isEmpty) continue;
        if (PrivacyCopyPolicy.isMachineIdentifierLiteral(value)) continue;
        // Scoped to privacy and trust text: see PrivacyCopyPolicy.isTrustCopy.
        if (!PrivacyCopyPolicy.isTrustCopy(value)) continue;
        if (deferredToOtherOwners.contains(value)) continue;
        byValue.putIfAbsent(value, () => []).add(declaration);
      }

      final duplicated = byValue.entries
          .where((entry) => entry.value.length > 1)
          .map(
            (entry) =>
                '"${entry.key}"\n    '
                '${entry.value.map((d) => '${d.location} ${d.name}').join('\n    ')}',
          )
          .toList()
        ..sort();

      expect(
        duplicated,
        isEmpty,
        reason:
            'These claims are typed out more than once. Move the wording into '
            'PrivacyClaimCatalogue and alias it — an alias or an interpolated '
            'composition does not fail this gate:\n\n'
            '${duplicated.join('\n\n')}',
      );
    });

    test('deliberate aliases do not trip the gate', () {
      // Sharing wording across surfaces is the intended outcome, so these
      // pairs must stay legal however identical they read.
      final aliased = declarations.where(
        (d) =>
            d.kind == CopyDeclarationKind.alias ||
            d.kind == CopyDeclarationKind.composition,
      );
      for (final name in const [
        'pillar2Title',
        'pillar3Title',
        'lede',
        'architectureHeading',
        'onDeviceProcessingTitle',
        'cardTitle',
        'archivePrivateTitle',
      ]) {
        expect(
          aliased.any((d) => d.name == name),
          isTrue,
          reason: '$name should reach its wording by reference, not by retype',
        );
      }
    });

    test('the reader reports shapes it cannot model instead of skipping', () {
      final unparsed = declarations
          .where((d) => d.kind == CopyDeclarationKind.unparsed)
          .where((d) => isLive(d.path))
          .length;
      // A hard cap rather than zero: `lib/` holds plenty of non-string
      // `static const`. This fails if a refactor makes the reader blind.
      expect(unparsed / declarations.length, lessThan(0.6));
    });
  });

  group('gate: claim-level contradiction', () {
    test('the catalogue itself contradicts nothing', () {
      for (final claim in PrivacyClaimCatalogue.all) {
        expect(
          PrivacyCopyPolicy.contradictoryClaimViolations(claim),
          isEmpty,
          reason: claim,
        );
      }
    });

    test('no live privacy copy pairs a remote word with an automatic one', () {
      final offenders = <String>[];
      for (final declaration in declarations) {
        if (declaration.kind != CopyDeclarationKind.literal) continue;
        if (!isLive(declaration.path)) continue;
        final reasons = PrivacyCopyPolicy.unpromptedRemoteProcessingViolations(
          declaration.literalValue!,
        );
        for (final reason in reasons) {
          offenders.add(
            '${declaration.location} ${declaration.name}: $reason in '
            '"${declaration.literalValue}"',
          );
        }
      }
      offenders.sort();
      expect(
        offenders,
        isEmpty,
        reason:
            'Nothing sends on its own — remote work needs a per-purpose grant. '
            'Copy that calls it automatic tells a user who declined that their '
            'data went anyway:\n${offenders.join('\n')}',
      );
    });

    test('no live encryption claim drops its subject or platform scope', () {
      final offenders = <String>[];
      for (final declaration in declarations) {
        if (declaration.kind != CopyDeclarationKind.literal) continue;
        if (!isLive(declaration.path)) continue;
        // Storage keys like `sqlite_encryption_key_v2` are addresses, not
        // sentences; nobody reads them.
        if (PrivacyCopyPolicy.isMachineIdentifierLiteral(
          declaration.literalValue!,
        )) {
          continue;
        }
        final reasons = PrivacyCopyPolicy.unscopedEncryptionViolations(
          declaration.literalValue!,
        );
        for (final reason in reasons) {
          offenders.add(
            '${declaration.location} ${declaration.name}: $reason in '
            '"${declaration.literalValue}"',
          );
        }
      }
      offenders.sort();
      expect(
        offenders,
        isEmpty,
        reason:
            'The journal file is AES-GCM on every platform; the database that '
            'indexes it is SQLCipher on iOS and Android only. A claim has to '
            'say which:\n${offenders.join('\n')}',
      );
    });

    test('the rules reject the wording they exist to catch', () {
      for (final rejected in const [
        'Your data is encrypted on this device.',
        'Everything is encrypted in your vault.',
        'Your entries live in an encrypted database.',
        'Encryption at rest protects what you save.',
      ]) {
        expect(
          PrivacyCopyPolicy.unscopedEncryptionViolations(rejected),
          isNotEmpty,
          reason: rejected,
        );
      }
      for (final rejected in const [
        'Cloud analysis runs automatically when local confidence is low.',
        'Remote transcription is a rare fallback.',
        'Our servers pick it up behind the scenes.',
      ]) {
        expect(
          PrivacyCopyPolicy.unpromptedRemoteProcessingViolations(rejected),
          isNotEmpty,
          reason: rejected,
        );
      }
    });
  });
}
