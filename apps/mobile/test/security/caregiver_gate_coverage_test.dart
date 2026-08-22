// Source-level tripwire for the caregiver access boundary.
//
// The behavioural coverage lives in `caregiver_session_guard_test.dart` and
// `test/features/caregiver/`. This file exists for the failure those cannot
// catch: an export path added later that nobody remembers to gate, or a
// per-stream exemption reintroduced into the read gate the way
// `insight_alerts` once was. It reads source rather than behaviour on purpose —
// a missing gate has no behaviour to assert against.
//
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guard = 'CaregiverSessionGuard';

/// Every service-layer entry point that hands over archive content or writes
/// into the journal. Adding a new one without adding it here is the gap this
/// file is for.
const _gatedEntryPoints = <String, List<String>>{
  'lib/services/account_data_portability_service.dart': ['buildZipExport'],
  'lib/security/private_data_service.dart': ['buildSanitizedExport'],
  'lib/features/export/journal_bulk_export_service.dart': ['buildExport'],
  'lib/services/journal_service.dart': ['exportJson'],
  'lib/sync/cloud_backup_service.dart': ['exportBackup'],
  // Strips `localAudioPath` but writes every transcript to a shared file.
  'lib/features/local_backup/local_backup_restore_service.dart': [
    'exportBackup',
  ],
  'lib/features/export/selected_archive_export.dart': ['buildOwnerMarkdown'],
  // Original recording audio, which is a step past the counts, short excerpts
  // and summaries a caregiver session is shown — it is the writer's own voice,
  // including whatever was said around the part that got quoted.
  'lib/audio/playback_service.dart': ['playFile'],
  'lib/features/archive_theory/citation_playback_launcher.dart': ['play'],
  'lib/services/capture_pipeline_service.dart': [
    'run',
    'attachTypedTextToVoiceEntry',
    'savePostSaveMomentDetail',
    'saveTextThought',
    'saveImageCaptionEntry',
    'saveLiveVoiceTranscript',
    'saveRecoveredVaultEntry',
    'runWatchCapture',
  ],
};

/// Drops the quotes and line breaks Dart puts through a wrapped string literal,
/// so a phrase can be searched for the way a reader sees it on screen.
String _flatten(String source) => source
    .replaceAll(RegExp("['\"]"), '')
    .replaceAll(RegExp(r'\s+'), ' ');

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path moved — update this test');
  return file.readAsStringSync();
}

void main() {
  group('owner-only surfaces stay gated', () {
    test('every export and capture entry point reaches the guard', () {
      for (final entry in _gatedEntryPoints.entries) {
        final source = _read(entry.key);
        expect(
          source,
          contains(_guard),
          reason:
              '${entry.key} no longer references $_guard. Every export hands '
              'over the whole archive and every capture writes under the '
              "owner's name; neither is covered by any scope the consent "
              'prompt offers.',
        );
        for (final method in entry.value) {
          expect(
            source,
            contains(method),
            reason: '${entry.key}.$method was renamed — re-check its gate',
          );
        }
      }
    });

    test('the router still calls the caregiver redirect', () {
      // It was dead code once: `tryRedirectFor` existed with no caller, so the
      // isolation it implements did nothing.
      expect(
        _read('lib/router/app_router.dart'),
        contains('CaregiverModeController.tryRedirectFor'),
        reason: 'caregiver route isolation is dead code again',
      );
    });
  });

  group('the read gate keeps no per-stream exemption', () {
    test('ensureReadAllowed exempts no stream id by name', () {
      final source = _read(
        'lib/features/caregiver/caregiver_mode_controller.dart',
      );
      final gate = source.substring(source.indexOf('ensureReadAllowed'));

      // The original read `!session.permissions.allowsStream(streamId) &&
      // streamId != CaregiverPermissions.insightAlertsStream`, which shared
      // alerts with a session that had declined them.
      expect(
        RegExp(r'streamId\s*!=').hasMatch(gate),
        isFalse,
        reason:
            'a stream id is exempted from the permission check by name again. '
            'If a stream cannot pass the check, the answer is to give it a '
            'permission, not to skip the check — and an internal reader that '
            'needs the data should not be going through a caregiver gate at '
            'all.',
      );
    });

    test('allowsStream resolves both boolean consent choices', () {
      final source = _read('lib/features/caregiver/caregiver_models.dart');

      expect(source, contains('insightAlertsStream => thresholdAlerts'));
      expect(source, contains('reviewSummariesStream => reviewSummaries'));
    });
  });

  group('the copy that describes the gate', () {
    // These strings were written when the limits really were UI-absence. They
    // have been rewritten against what the guard does; the risk now runs the
    // other way, so this pins both edges: no sliding back to "unchecked", and
    // no widening to a claim that holds off this device.
    const deviceScope = 'on this device';

    test('no string still says the limits are unchecked', () {
      final claims = {
        'lib/features/auth/domain/caregiver_access_copy.dart': [
          'Intended limits, not enforced ones',
          'rather than from a permission check',
          'intent rather than a guarantee',
        ],
        'lib/features/caregiver/caregiver_copy.dart': [
          'portability path checks the session role',
        ],
        'lib/features/caregiver_grant/caregiver_grant_copy.dart': [
          'not from a separate check',
        ],
      };

      for (final entry in claims.entries) {
        final source = _flatten(_read(entry.key));
        for (final stale in entry.value) {
          expect(
            source,
            isNot(contains(stale)),
            reason:
                '${entry.key} still says the limits are unchecked. Export, '
                'capture and audio playback all reach $_guard now, and telling '
                'someone a limit is weaker than it is has its own cost.',
          );
        }
      }
    });

    test('every strengthened claim carries the device scope', () {
      // There is no server-side caregiver read API, so "enforced" without the
      // scope would be a wider promise than the code delivers rather than a
      // corrected one.
      for (final path in const [
        'lib/features/auth/domain/caregiver_access_copy.dart',
        'lib/features/caregiver/caregiver_copy.dart',
        'lib/features/caregiver_grant/caregiver_grant_copy.dart',
      ]) {
        expect(
          _read(path).toLowerCase(),
          contains(deviceScope),
          reason: '$path claims enforcement without saying where it holds',
        );
      }
    });

    test('the blockers doc still names what is owed', () {
      final doc = _read('docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md');

      // Blocker 4 has no production writer and no decision yet.
      expect(doc, contains('MultiPartyAccessRole.observer'));
      // The caregiver revoke copy still describes a token that survives on the
      // server, which stopped being true when Blocker 2 closed.
      expect(doc, contains('CaregiverAccessCopy.revokeConfirmBody'));
      // Both remaining export surfaces are gated now, so the doc has to name
      // their gates rather than list them as reachable.
      expect(doc, contains('LocalBackupRestoreService.exportBackup'));
      expect(doc, contains('SelectedArchiveExport.buildOwnerMarkdown'));
      // The sync formatter is still what the share sheet calls. Until that
      // one-line switch lands the path is gated but not yet routed through it.
      expect(doc, contains('export_selected_sheet.dart'));
    });
  });
}
