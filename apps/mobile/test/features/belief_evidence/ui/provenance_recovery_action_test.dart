import 'dart:io';

import 'package:archiveme_mobile/features/belief_evidence/evidence/legacy_transcript_registry.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery/provenance_recovery_port.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/provenance_recovery_action.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _settingName = 'Keep processing on this device';

/// Fails the test on any attempt to open a socket.
///
/// The assertion that matters is not "the method returned false" — it is that
/// no byte left the process. A spy that fails on contact proves that; a return
/// value only proves the code path we happened to look at.
class _NoNetworkAllowed extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    fail('Rendering the recovery affordance opened an HTTP client.');
  }
}

/// A port that records calls and refuses to be reached by accident.
class _SpyPort implements ProvenanceRecoveryPort {
  final List<List<String>> calls = [];

  @override
  Future<ProvenanceRecoveryOutcome> recover(List<String> entryIds) async {
    calls.add(List<String>.of(entryIds));
    return ProvenanceRecoveryOutcome(
      requestedCount: entryIds.length,
      recoveredCount: entryIds.length,
    );
  }
}

class _NeverRecoversPort implements ProvenanceRecoveryPort {
  @override
  Future<ProvenanceRecoveryOutcome> recover(List<String> entryIds) async =>
      ProvenanceRecoveryOutcome(
        requestedCount: entryIds.length,
        recoveredCount: 0,
      );
}

RemoteTranscriptionConsentReader _consent({
  required bool onDeviceOnly,
  required bool permitted,
}) {
  return () async => RemoteProcessingConsentDecision(
    purpose: RemoteProcessingPurpose.remoteTranscription,
    permitted: permitted && !onDeviceOnly,
    consentAtProcessingTime: permitted && !onDeviceOnly,
    currentPermission: permitted,
    onDeviceProcessingOnly: onDeviceOnly,
  );
}

ProvenanceRecoveryPlanner _planner({
  bool onDeviceOnly = false,
  bool permitted = true,
  bool needsRemoteProcessing = true,
  Set<String> withAudio = const {'entry_a'},
}) {
  return ProvenanceRecoveryPlanner(
    readConsent: _consent(onDeviceOnly: onDeviceOnly, permitted: permitted),
    needsRemoteProcessing: needsRemoteProcessing,
    hasAudio: withAudio.contains,
  );
}

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpAction(
  WidgetTester tester, {
  required ProvenanceRecoveryPlanner planner,
  required ProvenanceRecoveryPort port,
  List<String> entryIds = const ['entry_a'],
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _host(
      ProvenanceRecoveryAction(
        entryIds: entryIds,
        planner: planner,
        port: port,
        onDeviceSettingName: _settingName,
      ),
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late HttpOverrides? previousOverrides;

  setUp(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _NoNetworkAllowed();
    LegacyTranscriptRegistry.resetForTest();
  });

  tearDown(() {
    HttpOverrides.global = previousOverrides;
    LegacyTranscriptRegistry.resetForTest();
  });

  group('nothing runs without a tap', () {
    testWidgets('rendering reaches neither the port nor the network', (
      tester,
    ) async {
      final port = _SpyPort();
      await _pumpAction(tester, planner: _planner(), port: port);

      expect(find.byKey(ProvenanceRecoveryAction.actionKey), findsOneWidget);
      expect(port.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening the disclosure sheet still runs nothing', (
      tester,
    ) async {
      final port = _SpyPort();
      await _pumpAction(tester, planner: _planner(), port: port);

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProvenanceRecoveryAction.sheetKey), findsOneWidget);
      expect(port.calls, isEmpty);
    });

    testWidgets('dismissing the sheet runs nothing', (tester) async {
      final port = _SpyPort();
      await _pumpAction(tester, planner: _planner(), port: port);

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProvenanceRecoveryAction.cancelKey));
      await tester.pumpAndSettle();

      expect(port.calls, isEmpty);
    });

    testWidgets('confirming is what starts the work', (tester) async {
      final port = _SpyPort();
      await _pumpAction(tester, planner: _planner(), port: port);

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      expect(port.calls, [
        ['entry_a'],
      ]);
    });
  });

  group('the sheet says what will happen before it happens', () {
    testWidgets('names the scope, the mechanism, and the receiver', (
      tester,
    ) async {
      await _pumpAction(tester, planner: _planner(), port: _SpyPort());
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.text(ProvenanceRecoveryCopy.scopeFor(1)), findsOneWidget);
      expect(find.text(ProvenanceRecoveryCopy.whatItDoes), findsOneWidget);
      expect(
        find.text(ProvenanceRecoveryCopy.remoteDisclosure),
        findsOneWidget,
      );
      expect(
        ProvenanceRecoveryCopy.remoteDisclosure,
        contains('OpenAI Whisper'),
      );
    });

    testWidgets('drops the server paragraph once work is local', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        planner: _planner(needsRemoteProcessing: false),
        port: _SpyPort(),
      );
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.text(ProvenanceRecoveryCopy.remoteDisclosure), findsNothing);
      expect(find.text(ProvenanceRecoveryCopy.consentReminder), findsNothing);
      // The action itself survives the mechanism changing: same title, same
      // confirm button, one paragraph fewer.
      expect(
        find.descendant(
          of: find.byKey(ProvenanceRecoveryAction.sheetKey),
          matching: find.text(ProvenanceRecoveryCopy.sheetTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(ProvenanceRecoveryCopy.whatItDoes), findsOneWidget);
      expect(find.byKey(ProvenanceRecoveryAction.confirmKey), findsOneWidget);
    });
  });

  group('closed gates are explained, not hidden', () {
    testWidgets('the on-device switch is named, with what to change', (
      tester,
    ) async {
      final port = _SpyPort();
      await _pumpAction(
        tester,
        planner: _planner(onDeviceOnly: true),
        port: port,
      );

      // The button is still there — a silently disabled control teaches
      // nothing.
      expect(find.byKey(ProvenanceRecoveryAction.actionKey), findsOneWidget);
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProvenanceRecoveryAction.blockedKey), findsOneWidget);
      expect(
        find.text(ProvenanceRecoveryCopy.onDeviceOnlyBlocker(_settingName)),
        findsOneWidget,
      );
      expect(find.byKey(ProvenanceRecoveryAction.confirmKey), findsNothing);
      expect(port.calls, isEmpty);
    });

    testWidgets('a missing transcription permission is explained', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        planner: _planner(permitted: false),
        port: _SpyPort(),
      );
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(
        find.text(ProvenanceRecoveryCopy.transcriptionNotPermittedBlocker),
        findsOneWidget,
      );
      expect(find.byKey(ProvenanceRecoveryAction.confirmKey), findsNothing);
    });

    testWidgets('both closed gates are explained together', (tester) async {
      await _pumpAction(
        tester,
        planner: _planner(onDeviceOnly: true, permitted: false),
        port: _SpyPort(),
      );
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      final combined = ProvenanceRecoveryCopy.bothBlockers(_settingName);
      expect(find.text(combined), findsOneWidget);
      expect(
        combined,
        contains(ProvenanceRecoveryCopy.transcriptionNotPermittedBlocker),
      );
    });

    testWidgets('the default gate state offers no confirm button', (
      tester,
    ) async {
      // Both conditions at their shipped defaults: the switch on, consent
      // ungranted. The default outcome has to be that nothing is sent.
      await _pumpAction(
        tester,
        planner: _planner(onDeviceOnly: true, permitted: false),
        port: _SpyPort(),
      );
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProvenanceRecoveryAction.confirmKey), findsNothing);
    });
  });

  group('audio has to still exist', () {
    testWidgets('no button at all when the recording is gone', (tester) async {
      final port = _SpyPort();
      await _pumpAction(
        tester,
        planner: _planner(withAudio: const {}),
        port: port,
      );

      expect(find.byKey(ProvenanceRecoveryAction.actionKey), findsNothing);
      expect(
        find.byKey(ProvenanceRecoveryAction.audioMissingKey),
        findsOneWidget,
      );
      expect(find.text(ProvenanceRecoveryCopy.audioMissing), findsOneWidget);
      expect(port.calls, isEmpty);
    });

    testWidgets('bulk wording when none of many have a recording', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        planner: _planner(withAudio: const {}),
        entryIds: const ['entry_a', 'entry_b'],
        port: _SpyPort(),
      );

      expect(
        find.text(ProvenanceRecoveryCopy.audioMissingBulk),
        findsOneWidget,
      );
    });

    test('the registry probes the filesystem, not just the stored path', () {
      LegacyTranscriptRegistry.remember(
        const LegacyTranscriptRecord(
          entryId: 'has_path',
          audioPath: '/tmp/archiveme-not-here.m4a',
        ),
      );
      LegacyTranscriptRegistry.remember(
        const LegacyTranscriptRecord(entryId: 'no_path'),
      );

      // Path recorded, file gone.
      expect(LegacyTranscriptRegistry.hasRecoverableAudio('has_path'), isFalse);
      expect(LegacyTranscriptRegistry.hasRecoverableAudio('no_path'), isFalse);

      LegacyTranscriptRegistry.audioProbe = (path) => true;
      expect(LegacyTranscriptRegistry.hasRecoverableAudio('has_path'), isTrue);
      expect(LegacyTranscriptRegistry.hasRecoverableAudio('no_path'), isFalse);
    });

    test('a probe that throws reads as no audio', () {
      LegacyTranscriptRegistry.remember(
        const LegacyTranscriptRecord(entryId: 'boom', audioPath: '/tmp/x.m4a'),
      );
      LegacyTranscriptRegistry.audioProbe = (path) =>
          throw const FileSystemException('unreadable');

      expect(LegacyTranscriptRegistry.hasRecoverableAudio('boom'), isFalse);
    });
  });

  group('many entries', () {
    testWidgets('scope is stated before a bulk run', (tester) async {
      final port = _SpyPort();
      await _pumpAction(
        tester,
        planner: _planner(withAudio: const {'entry_a', 'entry_b', 'entry_c'}),
        entryIds: const ['entry_a', 'entry_b', 'entry_c'],
        port: port,
      );

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.text(ProvenanceRecoveryCopy.scopeFor(3)), findsOneWidget);
      expect(port.calls, isEmpty);

      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      expect(port.calls, [
        ['entry_a', 'entry_b', 'entry_c'],
      ]);
    });

    testWidgets('a partial scope says how many actually qualify', (
      tester,
    ) async {
      final port = _SpyPort();
      await _pumpAction(
        tester,
        // Only one of the three still has a recording on this device.
        planner: _planner(),
        entryIds: const ['entry_a', 'entry_b', 'entry_c'],
        port: port,
      );

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(
        find.text(
          ProvenanceRecoveryCopy.partialScopeFor(withAudio: 1, total: 3),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      // Entries with no recording are left out of the request entirely.
      expect(port.calls, [
        ['entry_a'],
      ]);
    });

    testWidgets('a single entry stays possible on its own', (tester) async {
      final port = _SpyPort();
      await _pumpAction(tester, planner: _planner(), port: port);

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();
      expect(find.text(ProvenanceRecoveryCopy.scopeFor(1)), findsOneWidget);
      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      expect(port.calls.single, hasLength(1));
    });
  });

  group('results', () {
    testWidgets('a recovery that found nothing says so without alarm', (
      tester,
    ) async {
      await _pumpAction(
        tester,
        planner: _planner(),
        port: _NeverRecoversPort(),
      );

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      expect(
        find.text(ProvenanceRecoveryCopy.outcomeNoneRecovered),
        findsOneWidget,
      );
    });

    testWidgets('the unwired default port reports honestly', (tester) async {
      await tester.pumpWidget(
        _host(
          ProvenanceRecoveryAction(
            entryIds: const ['entry_a'],
            planner: _planner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProvenanceRecoveryAction.confirmKey));
      await tester.pumpAndSettle();

      // Wiring is deferred, so the default must not look like success.
      expect(
        find.text(ProvenanceRecoveryCopy.outcomeNoneRecovered),
        findsOneWidget,
      );
    });
  });

  group('presentation', () {
    testWidgets('the button carries its scope in its semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpAction(
        tester,
        planner: _planner(withAudio: const {'entry_a', 'entry_b'}),
        entryIds: const ['entry_a', 'entry_b'],
        port: _SpyPort(),
      );

      final label = ProvenanceRecoveryCopy.actionSemantics(2);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(label, contains(ProvenanceRecoveryCopy.scopeFor(2)));
      handle.dispose();
    });

    testWidgets('button and sheet survive 3x text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpAction(
        tester,
        planner: _planner(onDeviceOnly: true),
        port: _SpyPort(),
        textScale: 3,
      );
      await tester.tap(find.byKey(ProvenanceRecoveryAction.actionKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ProvenanceRecoveryAction.sheetKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the plan itself', () {
    test('audio missing outranks a closed consent gate', () async {
      final plan = await _planner(
        onDeviceOnly: true,
        permitted: false,
        withAudio: const {},
      ).planFor(const ['entry_a']);

      expect(plan.blocker, ProvenanceRecoveryBlocker.audioMissing);
      expect(plan.canRun, isFalse);
    });

    test('local-only work needs no consent question', () async {
      final plan = await _planner(
        onDeviceOnly: true,
        permitted: false,
        needsRemoteProcessing: false,
      ).planFor(const ['entry_a']);

      expect(plan.blocker, isNull);
      expect(plan.canRun, isTrue);
    });

    test('both gates open is the only remote path to canRun', () async {
      Future<bool> canRun({
        required bool onDeviceOnly,
        required bool permitted,
      }) async => (await _planner(
        onDeviceOnly: onDeviceOnly,
        permitted: permitted,
      ).planFor(const ['entry_a'])).canRun;

      expect(await canRun(onDeviceOnly: false, permitted: true), isTrue);
      expect(await canRun(onDeviceOnly: true, permitted: true), isFalse);
      expect(await canRun(onDeviceOnly: false, permitted: false), isFalse);
      expect(await canRun(onDeviceOnly: true, permitted: false), isFalse);
    });
  });
}
