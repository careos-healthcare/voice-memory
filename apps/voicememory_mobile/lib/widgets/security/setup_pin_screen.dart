import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/archive_mobile_typography.dart';
import '../../security/app_lock_service.dart';
import '../../security/app_lock_settings.dart';
import '../../security/pin_hash.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Two-step PIN setup: create, then confirm. Used both for first-time
/// enablement and for changing the PIN (change requires an already
/// unlocked session — enforced by the service). Only the salted hash is
/// stored; the controllers are cleared as soon as the PIN is saved.
class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({
    super.key,
    required this.service,
    this.changeExisting = false,
  });

  final AppLockService service;

  /// True when replacing an existing PIN instead of enabling the lock.
  final bool changeExisting;

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _firstPin;
  bool _mismatch = false;
  bool _busy = false;

  bool get _confirming => _firstPin != null;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pin = _pinController.text;
    if (!PinHash.isValidPin(pin)) {
      setState(() => _mismatch = true);
      return;
    }
    if (!_confirming) {
      setState(() {
        _firstPin = pin;
        _mismatch = false;
        _pinController.clear();
      });
      return;
    }
    if (pin != _firstPin) {
      // Mismatched confirmation: start over with a clear, calm retry.
      setState(() {
        _mismatch = true;
        _firstPin = null;
        _pinController.clear();
      });
      return;
    }
    setState(() => _busy = true);
    final ok = widget.changeExisting
        ? await widget.service.changePin(pin)
        : await widget.service.enableWithPin(pin);
    _pinController.clear();
    _firstPin = null;
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('setup_pin_screen'),
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _confirming
                      ? AppLockCopy.setupConfirmTitle
                      : AppLockCopy.setupTitle,
                  key: const Key('setup_pin_title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppLockCopy.setupBody,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('setup_pin_field'),
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  autofocus: true,
                  maxLength: PinHash.maxLength,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => unawaited(_submit()),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: AppLockCopy.setupPinHint,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_mismatch) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppLockCopy.setupMismatch,
                    key: const Key('setup_pin_mismatch'),
                    style: ArchiveMobileTypography.responsiveHelper(
                      context,
                    ).copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('setup_pin_cta'),
                  onPressed: _busy ? null : () => unawaited(_submit()),
                  child: Text(
                    _confirming
                        ? AppLockCopy.setupSaveLabel
                        : AppLockCopy.setupContinueLabel,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppLockCopy.setupPrivacyLine,
                  textAlign: TextAlign.center,
                  style: ArchiveMobileTypography.responsiveHelper(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
