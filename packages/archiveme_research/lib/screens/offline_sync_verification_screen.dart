import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/features/offline_sync/archive_integrity_snapshot.dart';
import 'package:voicememory_mobile/features/offline_sync/offline_sync_journey_store.dart';
import 'package:voicememory_mobile/features/offline_sync/offline_sync_production_evidence.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/debug_only_unavailable.dart';

/// Offline sync production verification — physical device, evidence only.
class OfflineSyncVerificationScreen extends StatefulWidget {
  const OfflineSyncVerificationScreen({super.key});

  @override
  State<OfflineSyncVerificationScreen> createState() =>
      _OfflineSyncVerificationScreenState();
}

class _OfflineSyncVerificationScreenState
    extends State<OfflineSyncVerificationScreen> {
  static const int _targetOffline = 5;

  bool _airplaneOn = false;
  bool _baselineLocked = false;
  bool _restartVerified = false;
  bool _networkBack = false;
  int _eligible = 0;
  int _pending = 0;
  String _lastSync = '';
  String? _syncState;
  String? _message;
  String? _exportJson;
  bool _busy = false;

  OfflineSyncJourneyStore get _journey =>
      AppServices.instance.offlineSyncJourney;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final journal = AppServices.instance.journal;
    final store = AppServices.instance.journalStore;
    final eligible = await journal.loadEligible();
    final pending = await store.pendingSyncQueue();
    final lastSync = await AppServices.instance.sync.lastSyncLabel();
    final locked = await _journey.isBaselineLocked();
    final restart = await _journey.isRestartVerified();
    final atAirplane = await _journey.eligibleAtAirplane();
    final recorded = await _journey.reflectionsRecordedOffline();

    if (mounted) {
      setState(() {
        _eligible = eligible.length;
        _pending = pending.length;
        _lastSync = lastSync;
        _baselineLocked = locked;
        _restartVerified = restart;
        _syncState = pending.isEmpty
            ? 'No pending uploads'
            : '${pending.length} pending upload(s)';
        if (_airplaneOn && !locked) {
          final added = eligible.length - atAirplane;
          _message =
              'Offline: $added new eligible moment(s) since airplane mode (need $_targetOffline)';
        }
        if (locked) {
          _message =
              'Baseline locked: $recorded offline · eligible now: ${eligible.length} · pending: ${pending.length}';
        }
      });
    }
  }

  Future<void> _startAirplane() async {
    await _journey.reset();
    await _journey.markAirplaneModeStarted();
    setState(() {
      _airplaneOn = true;
      _baselineLocked = false;
      _restartVerified = false;
      _networkBack = false;
      _message =
          'Airplane mode noted. Record $_targetOffline moments on /record while offline.';
    });
    await _refresh();
  }

  Future<void> _lockBaseline() async {
    if (!_airplaneOn) {
      setState(() => _message = 'Start airplane mode step first');
      return;
    }
    final atStart = await _journey.eligibleAtAirplane();
    final added = _eligible - atStart;
    if (added < _targetOffline) {
      setState(
        () => _message =
            'Need $_targetOffline new eligible moments (have $added)',
      );
      return;
    }
    setState(() => _busy = true);
    final startSnap = await _journey.startSnapshot();
    final lockSnap = await ArchiveIntegritySnapshot.capture();
    final startSet = (startSnap?.reflectionTimestamps ?? []).toSet();
    final offlineTs = lockSnap.reflectionTimestamps
        .where((t) => !startSet.contains(t))
        .toList();
    await _journey.lockOfflineBaseline(
      reflectionsRecordedOffline: added,
      lockSnapshot: lockSnap,
      offlineTimestamps: offlineTs,
    );
    setState(() {
      _busy = false;
      _baselineLocked = true;
      _message =
          'Baseline locked ($added offline). Force-quit the app, reopen, then confirm restart.';
    });
    await _refresh();
  }

  Future<void> _verifyRestart() async {
    if (!_baselineLocked) {
      setState(() => _message = 'Lock baseline before restart check');
      return;
    }
    setState(() => _busy = true);
    final baseline = await _journey.baselineSnapshot();
    final now = await ArchiveIntegritySnapshot.capture();
    final ok =
        baseline != null &&
        baseline.timestampsMatch(now) &&
        baseline.eligibleCount == now.eligibleCount &&
        baseline.beliefPreservedComparedTo(now) &&
        baseline.evidencePreservedComparedTo(now);

    if (ok) {
      await _journey.markRestartVerified();
    }
    setState(() {
      _busy = false;
      _restartVerified = ok;
      _message = ok
          ? 'Restart verified — moments, timestamps, belief, and evidence match baseline'
          : 'Restart check failed — counts or archive state changed';
    });
    await _refresh();
  }

  Future<void> _networkRestored() async {
    await _journey.markNetworkRestored();
    setState(() {
      _networkBack = true;
      _message = 'Network restored — tap Sync (sign in if prompted)';
    });
  }

  Future<void> _sync() async {
    if (!_restartVerified) {
      setState(() => _message = 'Verify restart before sync');
      return;
    }
    setState(() => _busy = true);
    final result = await AppServices.instance.sync.syncNow();
    setState(() {
      _busy = false;
      _syncState = result.ok
          ? 'Synced — pushed ${result.pushed}, pulled ${result.pulled}'
          : result.message;
      _message = result.message;
    });
    await _refresh();
  }

  Future<void> _exportEvidence() async {
    setState(() => _busy = true);
    final physical = await OfflineSyncProductionEvidence.isPhysicalDevice();
    final baseline = await _journey.baselineSnapshot();
    final now = await ArchiveIntegritySnapshot.capture();
    final recorded = await _journey.reflectionsRecordedOffline();

    final offlineTs = await _journey.offlineTimestamps();
    final synced = await now.countSyncedFromBaseline(offlineTs);

    final beliefOk =
        baseline != null && baseline.beliefPreservedComparedTo(now);
    final evidenceOk =
        baseline != null && baseline.evidencePreservedComparedTo(now);
    final timestampsOk = baseline != null && baseline.timestampsMatch(now);
    final countsOk = recorded > 0 && recorded == synced;

    final json = await OfflineSyncProductionEvidence.toJson(
      success:
          _restartVerified &&
          _networkBack &&
          beliefOk &&
          evidenceOk &&
          timestampsOk &&
          countsOk,
      reflectionsRecordedOffline: recorded,
      reflectionsSynced: synced,
      beliefPreserved: beliefOk,
      evidencePreserved: evidenceOk,
      physicalDevice: physical,
    );

    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      setState(() {
        _busy = false;
        _exportJson = json;
        _message = physical && countsOk && beliefOk && evidenceOk
            ? 'PASSING export copied — commit offline_sync_tested.json'
            : 'Export copied — success stays false until full flow passes on physical device';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'Offline sync verify');
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Offline sync verify'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Physical device only — not simulator or emulator.\n'
            'Airplane mode → record $_targetOffline moments → restart → sync → export evidence.',
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          _stat('Eligible moments', '$_eligible'),
          _stat('Pending sync', '$_pending'),
          _stat('Last sync', _lastSync),
          _stat('Sync state', _syncState ?? '—'),
          if (_message != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _message!,
              style: const TextStyle(color: AppTheme.foreground, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          _step(
            '1. Airplane mode ON',
            OutlinedButton(
              onPressed: _busy ? null : _startAirplane,
              child: const Text('I enabled airplane mode'),
            ),
          ),
          _step(
            '2. Record $_targetOffline moments',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/record'),
                  child: const Text('Open Record'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy || !_airplaneOn ? null : _lockBaseline,
                  child: Text(
                    'Lock baseline ($_targetOffline recorded offline)',
                  ),
                ),
              ],
            ),
          ),
          _step(
            '3. Force app restart',
            OutlinedButton(
              onPressed: _busy || !_baselineLocked ? null : _verifyRestart,
              child: const Text('I force-quit and reopened — verify'),
            ),
          ),
          _step(
            '4. Reconnect network',
            OutlinedButton(
              onPressed: _busy ? null : _networkRestored,
              child: const Text('Network is back'),
            ),
          ),
          _step(
            '5. Sync',
            FilledButton(
              onPressed: _busy ? null : _sync,
              child: const Text('Sync now'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _exportEvidence,
            child: const Text('Export evidence JSON'),
          ),
          if (_exportJson != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              _exportJson!,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppTheme.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
