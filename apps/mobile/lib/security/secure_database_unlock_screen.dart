import 'dart:async';

import 'package:archiveme_mobile/security/secure_database_copy.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Full-screen biometric gate shown while SQLCipher keys are locked.
class SecureDatabaseUnlockScreen extends StatefulWidget {
  const SecureDatabaseUnlockScreen({
    required this.onUnlocked,
    super.key,
    this.lockService,
  });

  final Future<void> Function() onUnlocked;
  final SecureSqliteLockService? lockService;

  @override
  State<SecureDatabaseUnlockScreen> createState() =>
      _SecureDatabaseUnlockScreenState();
}

class _SecureDatabaseUnlockScreenState extends State<SecureDatabaseUnlockScreen> {
  SecureSqliteLockService get _lock =>
      widget.lockService ?? SecureSqliteLockService.instance;

  bool _busy = false;
  bool? _biometricsAvailable;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAvailability());
  }

  Future<void> _loadAvailability() async {
    final available = await _lock.biometricsAvailable();
    if (!mounted) return;
    setState(() => _biometricsAvailable = available);
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _lock.unlockWithBiometric();
      if (!ok) {
        if (!mounted) return;
        setState(
          () => _error = _biometricsAvailable == false
              ? SecureDatabaseCopy.unavailable
              : SecureDatabaseCopy.body,
        );
        return;
      }
      await widget.onUnlocked();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      key: const Key('secure_database_unlock_screen'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.enhanced_encryption_outlined, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                SecureDatabaseCopy.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                SecureDatabaseCopy.body,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              FilledButton(
                key: const Key('secure_database_unlock_button'),
                onPressed: _busy ? null : _unlock,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(SecureDatabaseCopy.unlockAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
