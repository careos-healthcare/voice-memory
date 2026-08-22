import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/app_lock_settings.dart';
import 'package:archiveme_mobile/security/pin_hash.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/security/wipe_local_archive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen lock shown before any archive content. PIN entry with an
/// optional biometric button; a failed or cancelled biometric simply falls
/// back to the PIN field. No archive content renders behind this screen.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.service, super.key});

  final AppLockService service;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _failed = false;
  bool _busy = false;
  bool _biometricsReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometrics());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometrics() async {
    final ready = await widget.service.biometricUnlockReady();
    if (!mounted) return;
    setState(() => _biometricsReady = ready);
  }

  Future<void> _submitPin() async {
    if (_busy) return;
    final pin = _pinController.text;
    if (!PinHash.isValidPin(pin)) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.service.verifyPin(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
      if (!ok) _pinController.clear();
    });
    // A successful unlock notifies the gate, which removes this screen.
  }

  Future<void> _tryBiometrics() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.service.attemptBiometricUnlock();
    if (!mounted) return;
    // On failure or cancel, stay here — the PIN field is the fallback.
    setState(() => _busy = false);
    if (!ok) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('app_lock_screen'),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppLockCopy.lockTitle,
                    textAlign: TextAlign.center,
                    style: ArchiveMobileTypography.responsiveSectionTitle(
                      context,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppLockCopy.lockBody,
                    textAlign: TextAlign.center,
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('app_lock_pin_field'),
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofocus: true,
                    maxLength: PinHash.maxLength,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _submitPin(),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppLockCopy.lockTryAgain,
                      key: const Key('app_lock_try_again'),
                      textAlign: TextAlign.center,
                      style: ArchiveMobileTypography.responsiveHelper(
                        context,
                      ).copyWith(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    key: const Key('app_lock_unlock_cta'),
                    onPressed: _busy ? null : _submitPin,
                    child: const Text(AppLockCopy.lockUnlockLabel),
                  ),
                  if (_biometricsReady) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      key: const Key('app_lock_biometric_cta'),
                      onPressed: _busy ? null : _tryBiometrics,
                      child: const Text(AppLockCopy.lockBiometricsLabel),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    key: const Key('app_lock_emergency_wipe'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final wiped = await showWipeLocalArchiveDialog(
                              context,
                            );
                            if (!mounted || !wiped) return;
                            await widget.service.disableAfterEmergencyWipe();
                          },
                    child: const Text(AppLockCopy.emergencyWipeLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}