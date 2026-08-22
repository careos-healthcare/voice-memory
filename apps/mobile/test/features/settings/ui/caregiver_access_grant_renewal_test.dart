// Owner-confirmed renewal, from the row through the dialog to each outcome.
//
// The service layer's own guarantees are covered in
// `test/features/auth/consent_renewal_test.dart`. What is only reachable from
// here is the part of the design that lives in the interaction:
//
// - the confirmation is dated to the tap, not to the moment the dialog opened,
//   so renewal works the same for someone who reads the sentence as for
//   someone who taps straight through;
// - nothing in the list moves before the server has confirmed, which is the
//   asymmetry with revoke and the reason it exists;
// - a renewal that does not land is over, not scheduled.
import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_renewal_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_renewal_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_revocation_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_grant_list.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../helpers/app_provider_scope.dart';

const _widgetSource = 'lib/features/settings/ui/caregiver_access_grant_list.dart';
const _outcomeSource = 'lib/features/auth/domain/consent_renewal_outcome.dart';

/// Overrides every method the widget calls, so the base class never reaches
/// prefs and no test in this file depends on `AppServices` being initialised.
class _FakeAccessService extends MultiPartyAccessService {
  _FakeAccessService({required this.grants, required this.outcome});

  List<MultiPartyAccessGrant> grants;
  ConsentRenewalOutcome outcome;

  /// When set, `renewGrant` blocks on it — the seam for asserting what the
  /// list looks like while the server has not answered yet.
  Completer<void>? gate;

  final renewals = <DateTime>[];
  int loads = 0;

  @override
  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    loads++;
    return grants;
  }

  @override
  Future<ConsentRenewalOutcome> renewGrant(
    MultiPartyAccessGrant grant, {
    required DateTime ownerConfirmedAt,
  }) async {
    renewals.add(ownerConfirmedAt);
    final pending = gate;
    if (pending != null) await pending.future;
    return outcome;
  }

  @override
  Future<ConsentRevocationOutcome> revokeGrant(
    MultiPartyAccessGrant grant,
  ) async => const ConsentRevocationOutcome(
    localRevoked: true,
    serverConfirmed: true,
    queuedForRetry: false,
  );
}

/// A caregiver grant with a seven-day window, so the prompt reads "7 days"
/// without anything hard-coding seven.
MultiPartyAccessGrant _caregiverGrant({
  String grantId = 'grant-care-1',
  DateTime? grantedAt,
  DateTime? expiresAt,
  MultiPartyAccessRole role = MultiPartyAccessRole.caregiver,
}) => MultiPartyAccessGrant(
  grantId: grantId,
  partyId: 'Ada',
  role: role,
  grantedAt: grantedAt ?? DateTime.utc(2026, 6),
  expiresAt: expiresAt ?? DateTime.utc(2026, 6, 8),
);

ConsentRenewalOutcome _confirmed({DateTime? newExpiresAt}) =>
    ConsentRenewalOutcome(
      renewed: true,
      previousGrantEnded: true,
      newGrantId: 'grant-care-2',
      newExpiresAt: newExpiresAt ?? DateTime.utc(2026, 6, 15),
    );

/// Formatted the way the widget formats it, so these cases assert the sentence
/// rather than the test runner's time zone.
String _day(DateTime value) => DateFormat.yMMMMd().format(value.toLocal());

String _rowExpiry(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? '')
    .firstWhere((text) => text.startsWith('Expires: '), orElse: () => '');

/// Source with comments removed, so a tripwire cannot be satisfied or tripped
/// by prose about the thing it is looking for.
String _codeOf(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path moved — update this test');
  return file
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  late DateTime clock;

  setUp(() {
    CaregiverFeatureFlags.debugOverride = true;
    clock = DateTime.utc(2026, 6, 4, 12);
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
  });

  /// The row and its dialog are taller than the default 800x600 surface once
  /// two buttons stack in the trailing slot; at the default size the finders
  /// come back empty rather than failing on the assertion under test.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<_FakeAccessService> pumpList(
    WidgetTester tester, {
    List<MultiPartyAccessGrant>? grants,
    ConsentRenewalOutcome? outcome,
  }) async {
    final service = _FakeAccessService(
      grants: grants ?? [_caregiverGrant()],
      outcome: outcome ?? _confirmed(),
    );

    useTallSurface(tester);
    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CaregiverAccessGrantList(
                accessService: service,
                nowOverride: () => clock,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> openRenewDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('caregiver_access_renew_grant-care-1')));
    await tester.pumpAndSettle();
  }

  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('caregiver_access_renew_confirm_grant-care-1')),
    );
    await tester.pumpAndSettle();
  }

  /// Confirms and stops, without waiting for the screen to come to rest.
  ///
  /// `pumpAndSettle` cannot be used while a renewal is in flight: the button
  /// shows a progress indicator, which never stops animating, so settling is
  /// only reachable once the server has answered — which is the state these
  /// cases are trying to observe from the outside.
  Future<void> tapConfirmWithoutSettling(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('caregiver_access_renew_confirm_grant-care-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  group('the confirmation is dated to the tap', () {
    testWidgets(
      'a reader who sits with the dialog open confirms at the moment they tap',
      (tester) async {
        // The whole point of the confirmation step is that someone stops and
        // reads it. The server rejects a confirmation more than a few minutes
        // old, so a timestamp taken when the dialog opened would renew fine
        // for whoever taps straight through and fail for exactly the person
        // this step exists for.
        final service = await pumpList(tester);
        final openedAt = clock;

        await openRenewDialog(tester);

        clock = openedAt.add(const Duration(minutes: 6));
        await tapConfirm(tester);

        expect(service.renewals, hasLength(1));
        expect(
          service.renewals.single,
          clock,
          reason: 'the confirmation is the tap, not the sheet opening',
        );
        expect(
          service.renewals.single,
          isNot(openedAt),
          reason:
              'dating it to the open would send a confirmation six minutes '
              'stale — past what the server accepts',
        );
      },
    );

    testWidgets('cancelling asks for nothing at all', (tester) async {
      final service = await pumpList(tester);
      await openRenewDialog(tester);

      await tester.tap(
        find.byKey(const Key('caregiver_access_renew_cancel_grant-care-1')),
      );
      await tester.pumpAndSettle();

      expect(service.renewals, isEmpty);
      expect(find.text(CaregiverRenewalCopy.renewAccessCta), findsOneWidget);
    });
  });

  group('nothing in the list moves before the server confirms', () {
    testWidgets('the window on the row is unchanged while the call is open', (
      tester,
    ) async {
      final service = await pumpList(tester);
      final before = _rowExpiry(tester);
      expect(before, isNotEmpty);

      service.gate = Completer<void>();
      await openRenewDialog(tester);
      await tapConfirmWithoutSettling(tester);

      // The confirmation has been carried to the service and the server has
      // not answered. This is the moment a device that minted its own
      // credential would already be showing a longer window.
      expect(service.renewals, hasLength(1));
      expect(
        _rowExpiry(tester),
        before,
        reason:
            'renewal changes nothing locally until the server confirms — the '
            'opposite of revoke, which takes effect here first',
      );
      expect(
        find.text(CaregiverRenewalCopy.successSnack(_day(DateTime.utc(2026, 6, 15)))),
        findsNothing,
      );

      service.gate!.complete();
      await tester.pumpAndSettle();

      expect(_rowExpiry(tester), isNot(before));
    });

    testWidgets('a refusal leaves the window exactly as it was', (
      tester,
    ) async {
      final service = await pumpList(
        tester,
        outcome: ConsentRenewalOutcome.refused('server_unavailable'),
      );
      final before = _rowExpiry(tester);

      await openRenewDialog(tester);
      await tapConfirm(tester);

      expect(_rowExpiry(tester), before);
      expect(find.text(CaregiverRenewalCopy.unavailableSnack), findsOneWidget);
      expect(service.loads, 1, reason: 'nothing to reload — nothing moved');
    });
  });

  group('each outcome gets its own answer', () {
    testWidgets('a confirmed renewal names the day the new window ends', (
      tester,
    ) async {
      final newExpiry = DateTime.utc(2026, 6, 15);
      await pumpList(tester, outcome: _confirmed(newExpiresAt: newExpiry));

      await openRenewDialog(tester);
      await tapConfirm(tester);

      expect(
        find.text(CaregiverRenewalCopy.successSnack(_day(newExpiry))),
        findsOneWidget,
      );
      expect(_rowExpiry(tester), contains(DateFormat.yMMMd().format(newExpiry.toLocal())));
    });

    testWidgets('an unsettled result sends the owner back to the list', (
      tester,
    ) async {
      // A successor exists but this device was not told the predecessor ended.
      // Describing that as renewed would be describing one arrangement while
      // two credentials may be live.
      final service = await pumpList(
        tester,
        outcome: ConsentRenewalOutcome(
          renewed: true,
          previousGrantEnded: false,
          newGrantId: 'grant-care-2',
          newExpiresAt: DateTime.utc(2026, 6, 15),
        ),
      );

      await openRenewDialog(tester);
      await tapConfirm(tester);

      expect(find.text(CaregiverRenewalCopy.unsettledSnack), findsOneWidget);
      expect(
        find.text(CaregiverRenewalCopy.successSnack(_day(DateTime.utc(2026, 6, 15)))),
        findsNothing,
        reason:
            'an end date is available here, so only the branch order stops '
            'this being reported as a finished renewal',
      );
      expect(service.loads, 2, reason: 'the list is the thing to check, so re-read it');
    });

    testWidgets('a renewal with no end date to name is not announced as one', (
      tester,
    ) async {
      final service = await pumpList(
        tester,
        outcome: const ConsentRenewalOutcome(
          renewed: true,
          previousGrantEnded: true,
          newGrantId: 'grant-care-2',
        ),
      );

      await openRenewDialog(tester);
      await tapConfirm(tester);

      expect(find.text(CaregiverRenewalCopy.unsettledSnack), findsOneWidget);
      expect(service.loads, 2);
    });

    for (final code in ['grant_expired', 'not_renewable']) {
      testWidgets('$code offers a fresh grant rather than a retry', (
        tester,
      ) async {
        final service = await pumpList(
          tester,
          outcome: ConsentRenewalOutcome.refused(code),
        );

        await openRenewDialog(tester);
        await tapConfirm(tester);

        expect(find.text(CaregiverRenewalCopy.freshGrantSnack), findsOneWidget);
        expect(
          find.byKey(CaregiverDisclosureScreen.screenKey),
          findsOneWidget,
          reason: 'both settled answers lead to granting again, not to asking again',
        );
        expect(service.renewals, hasLength(1), reason: 'and never to a second attempt');
      });
    }

    for (final code in ['server_unavailable', 'network']) {
      testWidgets('$code says the current window is unchanged', (tester) async {
        await pumpList(tester, outcome: ConsentRenewalOutcome.refused(code));

        await openRenewDialog(tester);
        await tapConfirm(tester);

        expect(find.text(CaregiverRenewalCopy.unavailableSnack), findsOneWidget);
        expect(
          find.byKey(CaregiverDisclosureScreen.screenKey),
          findsNothing,
          reason: 'a window that may still be live is not a reason to grant again',
        );
      });
    }

    testWidgets('a refusal with no code at all still answers honestly', (
      tester,
    ) async {
      await pumpList(tester, outcome: ConsentRenewalOutcome.notAttempted);

      await openRenewDialog(tester);
      await tapConfirm(tester);

      expect(find.text(CaregiverRenewalCopy.unavailableSnack), findsOneWidget);
    });
  });

  group('nothing here schedules a renewal', () {
    testWidgets('mounting the list renews nothing', (tester) async {
      final service = await pumpList(tester);

      await tester.pump(const Duration(hours: 6));
      await tester.pumpAndSettle();

      expect(
        service.renewals,
        isEmpty,
        reason: 'a renewal on launch is a renewal the owner was not asked for',
      );
    });

    testWidgets('a renewal that did not land is over, not queued', (
      tester,
    ) async {
      final service = await pumpList(
        tester,
        outcome: ConsentRenewalOutcome.refused('network'),
      );

      await openRenewDialog(tester);
      await tapConfirm(tester);
      expect(service.renewals, hasLength(1));

      // Any timer or delayed retry the widget scheduled would fire inside this
      // span, because `pump` advances the test binding's clock.
      await tester.pump(const Duration(hours: 12));
      await tester.pumpAndSettle();

      expect(
        service.renewals,
        hasLength(1),
        reason:
            'a renewal landing at a moment nobody was asked is the scheduled '
            'extension this design rules out',
      );
    });

    test('the renewal path schedules nothing in source either', () {
      // Behaviour cannot catch a retry added behind a condition no test hits.
      final code = _codeOf(_widgetSource);
      // Written as patterns rather than literals because the type argument is
      // optional and free: `Future.delayed` and `Future<void>.delayed` are the
      // same scheduler, and a tripwire that only knows the first spelling
      // waves the second through.
      for (final scheduler in [
        RegExp(r'\bTimer\b'),
        RegExp(r'\bFuture(?:<[^>]*>)?\s*\.\s*delayed\b'),
        RegExp(r'\bscheduleMicrotask\b'),
        RegExp(r'\baddPostFrameCallback\b'),
        RegExp(r'\bflushPending\b'),
        RegExp('[Rr]etry'),
      ]) {
        expect(
          code,
          isNot(matches(scheduler)),
          reason:
              '${scheduler.pattern} in the renewal surface is how a '
              'confirmation the owner gave once becomes a standing instruction',
        );
      }
    });

    test('the outcome type still has no state a retry could hide in', () {
      final code = _codeOf(_outcomeSource);
      expect(
        code,
        isNot(contains('queuedForRetry')),
        reason:
            'revocation has that state because the user already decided; '
            'renewal must not, or a later flush extends access silently',
      );
    });
  });

  group('who the affordance is offered to', () {
    testWidgets('it is behind the caregiver capability flag', (tester) async {
      CaregiverFeatureFlags.debugOverride = false;
      await pumpList(tester);

      expect(
        find.byKey(const Key('caregiver_access_renew_grant-care-1')),
        findsNothing,
      );
      expect(find.text('Revoke Access'), findsOneWidget);
    });

    testWidgets('a coach grant is not offered renewal', (tester) async {
      await pumpList(
        tester,
        grants: [_caregiverGrant(role: MultiPartyAccessRole.coach)],
      );

      expect(
        find.byKey(const Key('caregiver_access_renew_grant-care-1')),
        findsNothing,
      );
    });

    testWidgets('a window that closed while the screen sat open is not offered', (
      tester,
    ) async {
      await pumpList(tester);
      expect(
        find.byKey(const Key('caregiver_access_renew_grant-care-1')),
        findsOneWidget,
      );

      clock = DateTime.utc(2026, 6, 9);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CaregiverAccessGrantList(
                  accessService: _FakeAccessService(
                    grants: [_caregiverGrant()],
                    outcome: _confirmed(),
                  ),
                  nowOverride: () => clock,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('caregiver_access_renew_grant-care-1')),
        findsNothing,
        reason: 'a lapsed window is granted again, not continued',
      );
    });

    testWidgets('a grant with no expiry has no window to continue', (
      tester,
    ) async {
      await pumpList(
        tester,
        grants: [
          MultiPartyAccessGrant(
            grantId: 'grant-care-1',
            partyId: 'Ada',
            role: MultiPartyAccessRole.caregiver,
            grantedAt: DateTime.utc(2026, 6),
          ),
        ],
      );

      expect(
        find.byKey(const Key('caregiver_access_renew_grant-care-1')),
        findsNothing,
      );
    });
  });

  group('what the prompt says', () {
    testWidgets('it names the person, the day it ends, and the length', (
      tester,
    ) async {
      await pumpList(tester);
      await openRenewDialog(tester);

      expect(
        find.text(CaregiverRenewalCopy.confirmTitle(partyLabel: 'Ada', days: 7)),
        findsOneWidget,
      );
      expect(
        find.text(
          CaregiverRenewalCopy.confirmBody(
            endsOn: _day(DateTime.utc(2026, 6, 8)),
            days: 7,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(CaregiverRenewalCopy.confirmCta(7)), findsOneWidget);
      expect(find.text(CaregiverRenewalCopy.cancelCta), findsOneWidget);
    });

    testWidgets('the length is read off the grant, not assumed', (
      tester,
    ) async {
      await pumpList(
        tester,
        grants: [
          _caregiverGrant(
            grantedAt: DateTime.utc(2026, 6),
            expiresAt: DateTime.utc(2026, 6, 15),
          ),
        ],
      );
      await openRenewDialog(tester);

      expect(
        find.text(CaregiverRenewalCopy.confirmTitle(partyLabel: 'Ada', days: 14)),
        findsOneWidget,
      );
      expect(find.text(CaregiverRenewalCopy.confirmCta(14)), findsOneWidget);
    });

    test('it says nothing about what a caregiver can see', () {
      // The read-only limits are a check this app runs on this device and no
      // server enforces them. Renewal copy that described the scope would lend
      // that claim the standing of the revocation sitting next to it.
      final strings = [
        CaregiverRenewalCopy.confirmTitle(partyLabel: 'Ada', days: 7),
        CaregiverRenewalCopy.confirmBody(endsOn: '4 March', days: 7),
        CaregiverRenewalCopy.confirmCta(7),
        CaregiverRenewalCopy.successSnack('11 March'),
        CaregiverRenewalCopy.freshGrantSnack,
        CaregiverRenewalCopy.unavailableSnack,
        CaregiverRenewalCopy.unsettledSnack,
        CaregiverRenewalCopy.renewAccessCta,
        CaregiverRenewalCopy.cancelCta,
      ].join(' ').toLowerCase();

      for (final claim in const [
        'read-only',
        'cannot see',
        "can't see",
        'can see',
        'transcript',
        'audio',
        'recording',
        'summaries',
      ]) {
        expect(strings, isNot(contains(claim)), reason: 'renewal copy: $claim');
      }
    });

    test('ending access keeps the device scope the rest of the surface uses', () {
      // The server's `verify` route consults no revocation list, so a token
      // already issued keeps verifying until its own expiry. "You can end it
      // sooner", unscoped, would be a promise this app cannot keep.
      final body = CaregiverRenewalCopy.confirmBody(
        endsOn: '4 March',
        days: 7,
      ).toLowerCase();
      expect(body, contains('on this device'));
      expect(body, isNot(contains('ends their access')));
      expect(body, isNot(contains('immediately')));
    });

    test('the settled refusal fits both answers it has to cover', () {
      // `shouldOfferFreshGrant` is true for `grant_expired` and
      // `not_renewable` alike, and the second is not a window that closed.
      expect(
        ConsentRenewalOutcome.refused('grant_expired').shouldOfferFreshGrant,
        isTrue,
      );
      expect(
        ConsentRenewalOutcome.refused('not_renewable').shouldOfferFreshGrant,
        isTrue,
      );
      expect(
        CaregiverRenewalCopy.freshGrantSnack.toLowerCase(),
        isNot(contains('window has closed')),
        reason: 'a withdrawn grant reaches this line too',
      );
    });
  });
}
