import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pushed_screen_shell.dart';
import 'account_data_migration_coordinator.dart';

/// Presents the "you have data from before you signed in" decision: move
/// it into this account, keep it separate, or export a copy first. Reached
/// manually today from Security & privacy settings (see
/// `SecuritySettingsScreen`) whenever
/// [AccountDataMigrationCoordinator.hasMigratableGuestData] is true.
class GuestDataMigrationScreen extends StatefulWidget {
  const GuestDataMigrationScreen({super.key, this.coordinator});

  /// Injectable for tests; defaults to a coordinator built against the
  /// live `AppServices.instance`.
  final AccountDataMigrationCoordinator? coordinator;

  @override
  State<GuestDataMigrationScreen> createState() =>
      _GuestDataMigrationScreenState();
}

class _GuestDataMigrationScreenState extends State<GuestDataMigrationScreen> {
  AccountDataMigrationCoordinator? _coordinator;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coordinator =
        widget.coordinator ??
        await AccountDataMigrationCoordinator.forActiveAccount();
    if (!mounted) return;
    setState(() {
      _coordinator = coordinator;
      _loading = false;
    });
  }

  Future<void> _move() => _runMigration(thenClearGuest: true);

  Future<void> _keepSeparate() async {
    setState(() => _busy = true);
    try {
      await _coordinator!.recordKeptSeparateDecision();
      if (!mounted) return;
      setState(() {
        _resolved = true;
        _message = 'Kept separate. Your signed-out data stays where it was.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runMigration({required bool thenClearGuest}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final coordinator = _coordinator!;
      final migrationId =
          AccountDataMigrationCoordinator.deterministicMigrationId(
            coordinator.activeNamespace,
          );
      final result = await coordinator.migrateGuestDataIntoActiveAccount(
        migrationId: migrationId,
      );
      if (!result.succeeded) {
        setState(() => _message = 'Nothing to move (${result.outcome.name}).');
        return;
      }
      if (thenClearGuest) {
        await coordinator.clearGuestDataAfterVerifiedMove();
      }
      if (!mounted) return;
      setState(() {
        _resolved = true;
        _message = thenClearGuest
            ? 'Moved ${result.entriesCopied} entries into this account.'
            : 'Copied ${result.entriesCopied} entries into this account.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Could not complete this action: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportGuestData() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final payload = await _coordinator!.exportGuestData();
      final json = payload.toJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/archiveme_guest_export.json');
      await file.writeAsString(json);
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'ArchiveMe signed-out data export');
      if (!mounted) return;
      setState(
        () => _message =
            'Exported ${payload.entries.length} entries. '
            'Decide below once you have your copy.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Data from before sign-in',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'You recorded reflections before signing in. Choose what '
                    'to do with that data now that you have an account.',
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('guest_migration_move'),
                    onPressed: (_busy || _resolved) ? null : _move,
                    icon: const Icon(Icons.move_up_outlined),
                    label: const Text('Move into this account'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copies your signed-out reflections into this account, '
                    'then clears the signed-out copy once the copy is verified.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('guest_migration_keep_separate'),
                    onPressed: (_busy || _resolved) ? null : _keepSeparate,
                    icon: const Icon(Icons.call_split_outlined),
                    label: const Text('Keep separate'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leaves your signed-out reflections exactly where they are; '
                    "this account won't see them.",
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('guest_migration_export'),
                    onPressed: _busy ? null : _exportGuestData,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Export a copy first'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Doesn't move or clear anything — just saves a copy so you "
                    'can decide later.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _message!,
                      key: const Key('guest_migration_message'),
                      style: TextStyle(
                        color: _resolved ? AppColors.success : AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
