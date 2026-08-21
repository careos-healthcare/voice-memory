import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/privacy/database_biometric_gate_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Biometric / passcode gate toggle for the encrypted local database.
class BiometricSecurityTile extends StatefulWidget {
  const BiometricSecurityTile({
    super.key,
    this.lockService,
    this.onChanged,
  });

  final SecureSqliteLockService? lockService;
  final VoidCallback? onChanged;

  @override
  State<BiometricSecurityTile> createState() => _BiometricSecurityTileState();
}

class _BiometricSecurityTileState extends State<BiometricSecurityTile> {
  bool _loading = true;
  bool _gateEnabled = DatabaseBiometricGateStore.defaultEnabled;
  bool _biometricsAvailable = false;
  String _biometricLabel =
      PrivacySecurityControlCenterCopy.biometricStatusBiometric;

  SecureSqliteLockService get _lock =>
      widget.lockService ?? SecureSqliteLockService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    await DatabaseBiometricGateStore.ensureLoaded();
    final available = await _lock.biometricsAvailable();
    final gateEnabled = DatabaseBiometricGateStore.enabled;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _biometricsAvailable = available;
      _gateEnabled = gateEnabled;
      _biometricLabel = _resolveBiometricLabel(available);
    });
  }

  String _resolveBiometricLabel(bool available) {
    if (!available) {
      return PrivacySecurityControlCenterCopy.biometricStatusPasscode;
    }
    if (Platform.isIOS) {
      return PrivacySecurityControlCenterCopy.biometricStatusFaceId;
    }
    if (Platform.isAndroid) {
      return PrivacySecurityControlCenterCopy.biometricStatusBiometric;
    }
    return PrivacySecurityControlCenterCopy.biometricStatusTouchId;
  }

  Future<void> _onToggle(bool enabled) async {
    setState(() => _gateEnabled = enabled);
    await DatabaseBiometricGateStore.setEnabled(enabled);
    PrivacySecurityEngagementAnalytics.biometricEnforcementToggled(
      enabled: enabled,
    );
    if (!enabled && _lock.isLocked) {
      await _lock.bootstrapUnlockedSession();
      if (AppServices.isInitialized) {
        await AppServices.instance.reopenSqliteDatabase();
      }
    }
    widget.onChanged?.call();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    final subtitle = _gateEnabled
        ? PrivacySecurityControlCenterCopy.biometricTileSubtitleEnabled
        : PrivacySecurityControlCenterCopy.biometricTileSubtitleDisabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('biometric_security_status_tile'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            _biometricLabel,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            _biometricsAvailable
                ? subtitle
                : PrivacySecurityControlCenterCopy.biometricUnavailableSubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ),
        SwitchListTile(
          key: const Key('biometric_security_gate_toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacySecurityControlCenterCopy.biometricTileTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          value: _gateEnabled,
          onChanged: SecureSqliteLockService.encryptionEnabled ? _onToggle : null,
        ),
      ],
    );
  }
}
