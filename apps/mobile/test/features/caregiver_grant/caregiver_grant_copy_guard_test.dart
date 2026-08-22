import 'dart:io';

import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Words that assert an access cut-off takes effect the moment it is made.
///
/// Deliberately *not* relaxed alongside [_reachPattern]. Revocation now
/// reaches the server, but not necessarily now: the local write happens first
/// and unconditionally, then `ServerConsentRevocationCoordinator` calls
/// `POST /api/coach/consent/revoke`, and a call that does not land is queued
/// in `PendingConsentRevocationStore` and retried on the next flush — across
/// restarts (`test/features/auth/server_consent_revocation_test.dart`). A
/// revoke made on a plane is local-only until the plane lands, so "immediately,
/// everywhere" is still a promise this product cannot keep, and immediacy is
/// truthful only when it is scoped to the device the user is holding.
final RegExp _immediacyPattern = RegExp(
  r'\bimmediate(?:ly)?\b|\binstant(?:ly)?\b|\bright away\b|\bat once\b'
  r'|\bstraight away\b|\bon the spot\b',
  caseSensitive: false,
);

/// Claims that a cut-off reaches past this device.
///
/// This used to be an outright ban, because revocation wrote to a local prefs
/// set and the server's verify path did not consult a revocation list at all.
/// Both halves of that changed: every revoke path now calls the revoke route,
/// and `verify` fails closed on a revoked token. So reach is real, and the
/// rule is no longer "do not claim it" but "do not claim it unqualified" —
/// a reach claim clears once the same line says where the guarantee stops,
/// either by scoping to this device ([_deviceScopePattern]) or by naming the
/// server round trip and its retry ([_serverScopePattern]).
final RegExp _reachPattern = RegExp(
  r'\bsevers?\b|\bsevering\b'
  r'|\bcuts? off\b|\bcutting off\b'
  r'|\bshuts? down (?:their|all)\b'
  r'|\beverywhere\b|\bon (?:all|every) devices?\b'
  r'|\blose[s]? (?:all )?access\b|\blost access\b'
  r'|\bcan no longer (?:see|read|view|access)\b'
  r'|\bkicked out\b|\blocked out\b'
  r'|\brevoke[sd]? the (?:token|pass)\b',
  caseSensitive: false,
);

/// Wording that keeps an immediacy claim honest by tying it to this device.
final RegExp _deviceScopePattern = RegExp(
  r'\bon this device\b|\bthis device\b|\bhere\b',
  caseSensitive: false,
);

/// Wording that names the server round trip, so a reach claim says where its
/// guarantee stops instead of implying the reach is already complete.
final RegExp _serverScopePattern = RegExp(
  r'\bserver\b|\boffline\b|\breconnect\b|\bback online\b|\bwhen you are on\b',
  caseSensitive: false,
);

/// A promise that access can be ended whenever, with no lifetime caveat.
final RegExp _unqualifiedRevokePattern = RegExp(
  r'\brevoke\b|\bwithdraw\b|\btake (?:it )?back\b',
  caseSensitive: false,
);

/// Copy that describes revocation as stopping at this device.
///
/// The mirror image of [_reachPattern], and the half that matters now. The
/// guard this file replaced could only fail on copy that promised too much,
/// so when the server revoke route was wired up the shipped copy quietly
/// became an understatement — telling a user their caregiver keeps reading
/// when the caregiver does not — and nothing went red. These phrases are the
/// exact sentences that were shipped, plus the shapes they would come back as.
final RegExp _localOnlyPattern = RegExp(
  r'\bdoes not shut down\b|\bdo(?:es)? not stop\b'
  r'|\bkeeps? working (?:somewhere else|elsewhere)\b'
  r'|\bcan keep working\b'
  r'|\bstays? valid on (?:the|our) server\b'
  r'|\b(?:only|just) on this device\b|\bon this device only\b'
  r'|\bno way to end\b|\bnot have a way to end\b'
  r'|\bwe cannot end\b|\bcannot be ended\b',
  caseSensitive: false,
);

/// Every reason [line] misstates what revocation does — in either direction.
List<String> revocationOverstatementsIn(String line) {
  final reasons = <String>[];

  if (_immediacyPattern.hasMatch(line) &&
      !_deviceScopePattern.hasMatch(line)) {
    reasons.add('immediacy claim not scoped to this device');
  }
  if (_reachPattern.hasMatch(line) &&
      !_deviceScopePattern.hasMatch(line) &&
      !_serverScopePattern.hasMatch(line)) {
    reasons.add('unqualified reach claim — says neither where nor when');
  }
  if (_unqualifiedRevokePattern.hasMatch(line) &&
      !_deviceScopePattern.hasMatch(line)) {
    reasons.add('unscoped revoke promise');
  }
  if (_localOnlyPattern.hasMatch(line)) {
    reasons.add('understates revocation — describes it as local-only');
  }

  return reasons;
}

/// Every reason [line] is unsafe consent copy — the widened privacy scanner
/// plus the revocation rules above.
List<String> overstatementsIn(String line) => [
  ...PrivacyCopyPolicy.violationsInLiteral(line),
  ...revocationOverstatementsIn(line),
];

/// Every Dart path whose job includes revoking a grant.
///
/// `consent_verification_service.dart` does only the local half, and is here
/// because it is where a future server call would most plausibly be added.
const List<String> revokePaths = [
  'lib/features/auth/application/multi_party_access_service.dart',
  'lib/features/caregiver/consent_verification_service.dart',
  'lib/features/consent_audit/consent_audit_service.dart',
  'lib/features/caregiver/caregiver_mode_controller.dart',
];

/// Any of the ways a revoke path can reach the server.
///
/// Naming only `ConsentRevocationApiClient` is what let the previous guard
/// sleep through the wiring: the paths call the endpoint through
/// `ServerConsentRevocationCoordinator.revokeOnServer`, and never mention the
/// client class.
final RegExp _serverRevocationWiring = RegExp(
  'ConsentRevocationApiClient|ServerConsentRevocationCoordinator'
  '|revokeOnServer',
);

/// The single declaration of the caregiver token lifetime.
const String _ttlSourcePath =
    '../../packages/shared/lib/consent/consent-token-ttl.ts';

/// The caregiver default TTL in whole days, read from its declaration.
///
/// Evaluated from the source rather than restated, so a change to the constant
/// fails this test instead of quietly disagreeing with the copy.
final int caregiverConsentTtlDays = _readCaregiverTtlDays();

int _readCaregiverTtlDays() {
  final file = File(_ttlSourcePath);
  if (!file.existsSync()) {
    throw StateError(
      'cannot check the pass lifetime: $_ttlSourcePath is missing. If the '
      'constant moved, repoint this test rather than deleting it.',
    );
  }

  final declaration = RegExp(
    r'CAREGIVER_CONSENT_DEFAULT_TTL_MS\s*=\s*([0-9*\s]+);',
  ).firstMatch(file.readAsStringSync());
  if (declaration == null) {
    throw StateError(
      'CAREGIVER_CONSENT_DEFAULT_TTL_MS is no longer declared as a product of '
      'literals in $_ttlSourcePath',
    );
  }

  final milliseconds = declaration
      .group(1)!
      .split('*')
      .map((part) => int.parse(part.trim()))
      .reduce((a, b) => a * b);
  return milliseconds ~/ Duration.millisecondsPerDay;
}

void main() {
  group('caregiver grant copy makes no claim the code cannot back', () {
    test('no line trips the privacy copy policy', () {
      final offenders = <String, List<String>>{};
      for (final line in CaregiverGrantCopy.all) {
        final violations = PrivacyCopyPolicy.violationsInLiteral(line);
        if (violations.isNotEmpty) offenders[line] = violations;
      }

      expect(offenders, isEmpty);
    });

    test('no line uses an absolute qualifier about a privacy subject', () {
      final offenders = CaregiverGrantCopy.all
          .where(PrivacyCopyPolicy.isUnscopedAbsoluteClaim)
          .toList();

      expect(offenders, isEmpty);
    });

    test('no line overstates what revoking does', () {
      final offenders = <String, List<String>>{};
      for (final line in CaregiverGrantCopy.all) {
        final reasons = revocationOverstatementsIn(line);
        if (reasons.isNotEmpty) offenders[line] = reasons;
      }

      expect(offenders, isEmpty);
    });

    test('the pass lifetime matches the constant it comes from', () {
      // Read, not retyped. This number was wrong for exactly as long as it was
      // a literal in a sentence with a comment pointing at a file that no
      // longer held it: the copy claimed 30 days, which is the *coach*
      // default, while a caregiver pass has always expired in 7.
      expect(
        CaregiverGrantCopy.stopPassLifetime,
        contains('$caregiverConsentTtlDays days'),
        reason:
            'CAREGIVER_CONSENT_DEFAULT_TTL_MS in $_ttlSourcePath is '
            '$caregiverConsentTtlDays days',
      );
    });

    test('the stop section says revocation reaches the server', () {
      final stopText = CaregiverGrantCopy.stop.join(' ').toLowerCase();

      expect(
        stopText,
        contains('server'),
        reason: 'every revoke path calls POST /api/coach/consent/revoke; copy '
            'that leaves the server out tells a user their caregiver can '
            'still read when they cannot',
      );
      expect(
        stopText,
        anyOf(contains('offline'), contains('reconnect')),
        reason: 'the server half is queued and retried when it does not land, '
            'so the bound belongs in the same section as the promise',
      );
      expect(
        CaregiverGrantCopy.stop,
        contains(CaregiverGrantCopy.stopOnThisDevice),
        reason: 'the device-scoped immediacy claim is the honest one and has '
            'to survive every rewrite of the section around it',
      );
    });

    test('the revocation copy still matches what the revoke path does', () {
      // The tripwire, pointed the other way round.
      //
      // It used to assert that the revoke paths did *not* reach the server,
      // so that wiring them up would go red and force this copy to be
      // rewritten. It never fired: both paths reach the endpoint through
      // `ServerConsentRevocationCoordinator`, so the literal it looked for —
      // `ConsentRevocationApiClient` — was in neither file, and the copy sat
      // there claiming a handed-out pass kept working elsewhere long after
      // that stopped being true. Detection is now the coordinator and the
      // call, not one class name, and the failure it protects against is the
      // copy sliding back to local-only.
      final wired = <String>[];
      final unwired = <String>[];
      for (final path in revokePaths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        (_serverRevocationWiring.hasMatch(file.readAsStringSync())
                ? wired
                : unwired)
            .add(path);
      }

      expect(
        wired,
        isNotEmpty,
        reason:
            'no revoke path reaches the server any more. Revocation is back to '
            'local-only, so CaregiverGrantCopy.stopReachesServer and '
            'stopEndEarly now overstate it — rewrite them before shipping.',
      );

      for (final line in CaregiverGrantCopy.stop) {
        expect(
          _localOnlyPattern.hasMatch(line),
          isFalse,
          reason:
              '${wired.join(', ')} reach the server revoke endpoint, so "$line" '
              'understates what turning access off does.',
        );
      }
    });

    test('the limits section names the check and says where it runs', () {
      final caveat = CaregiverGrantCopy.cannotCaveat.toLowerCase();

      // It used to say the limits came from "the way the caregiver screens are
      // built, not from a separate check". Export, capture and both audio
      // playback paths now run `CaregiverSessionGuard`, so that understates
      // them — and understating a limit has its own cost on this surface.
      expect(caveat, contains('checked'));
      expect(caveat, isNot(contains('not from a separate check')));

      // There is still no server-side caregiver read API for a check to sit in
      // front of, so dropping the device scope would be a new overstatement
      // rather than a correction.
      expect(caveat, contains('on this device'));
      expect(caveat, contains('rather than on a server'));
    });

    test('the entry subtitle does not promise care management', () {
      final subtitle = CaregiverGrantCopy.entrySubtitle.toLowerCase();
      for (final absent in [
        'manage your care',
        'appointment',
        'book',
        'care team',
        'message',
        'schedul',
      ]) {
        expect(subtitle, isNot(contains(absent)), reason: absent);
      }
    });

    test('no line mentions a product surface that does not exist', () {
      for (final line in CaregiverGrantCopy.all) {
        final lower = line.toLowerCase();
        for (final absent in [
          'appointment',
          'care team',
          'clinician',
          'prescription',
          'book a',
        ]) {
          expect(lower, isNot(contains(absent)), reason: '$absent in "$line"');
        }
      }
    });
  });

  group('the guard fails on deliberately overstated copy', () {
    const overstated = <String, String>{
      'Turning access off instantly severs their access.':
          'immediacy plus reach',
      'You can revoke access at any time.': 'unscoped revoke promise',
      'Revoking means they immediately lose access.': 'immediacy plus reach',
      'Once you turn this off they can no longer see your moments.':
          'reach beyond this device',
      'Access ends everywhere the moment you turn it off.': 'reach',
      'Your moments are never shared without your say-so.':
          'absolute privacy claim',
      'We guarantee your archive stays private.': 'guarantee',
      'Turning this off shuts down their pass on all devices.': 'reach',
    };

    for (final entry in overstated.entries) {
      test('rejects: ${entry.key}', () {
        expect(
          overstatementsIn(entry.key),
          isNotEmpty,
          reason: 'expected ${entry.value} to be caught',
        );
      });
    }

    test('every shipped line passes the same guard the overstatements fail', () {
      for (final line in CaregiverGrantCopy.all) {
        expect(overstatementsIn(line), isEmpty, reason: line);
      }
    });
  });

  group('the guard fails on copy that has gone stale the other way', () {
    // The first two entries are verbatim the strings this screen shipped with.
    // They were accurate when revocation was local-only and became wrong the
    // day the revoke route was wired in, and nothing failed. They are here so
    // that reintroducing them — or the shapes they would come back as — is red.
    const understated = <String, String>{
      'Turning access off here does not shut down a pass you already handed '
              'out. It can keep working somewhere else until it runs out.':
          'the shipped local-only claim',
      'We do not have a way to end a pass early yet.': 'the shipped no-op claim',
      'A consent token already issued stays valid on the server until its '
              'expiry date.':
          'the confirmation-dialog version of the same claim',
      'Revoking works only on this device.': 'scoping the whole cut-off local',
    };

    for (final entry in understated.entries) {
      test('rejects: ${entry.value}', () {
        expect(
          revocationOverstatementsIn(entry.key),
          isNotEmpty,
          reason: 'expected "${entry.key}" to be caught',
        );
      });
    }

    test('a device-scoped immediacy claim is still allowed', () {
      // The relaxation of the reach rule must not become a relaxation of the
      // immediacy rule. This line is true — the local write completes before
      // the network is touched — and it has to keep clearing the guard, while
      // the unscoped version of it below keeps failing.
      expect(
        revocationOverstatementsIn(CaregiverGrantCopy.stopOnThisDevice),
        isEmpty,
      );
      expect(
        revocationOverstatementsIn(
          'The caregiver view stops working right away.',
        ),
        isNotEmpty,
        reason: 'unscoped immediacy survives the reach relaxation',
      );
    });

    test('naming the server does not launder an immediacy claim', () {
      // The excuse added for reach claims is deliberately not an excuse for
      // immediacy ones: an offline revoke is queued, so nothing about the
      // server half happens the moment the user taps.
      expect(
        revocationOverstatementsIn(
          'Turning this off stops the pass on our server immediately.',
        ),
        contains('immediacy claim not scoped to this device'),
      );
    });
  });
}
