import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:flutter/material.dart';

/// Standalone caregiver-consent panel: local [setState] only.
///
/// Bare `const CaregiverConsentScreen()` is a preview fixture (sharing on,
/// Connected to Heather). Production Settings must pass [previewMode] `false`
/// and a real [caregiverDisplayName] only when a grant exists.
class CaregiverConsentScreen extends StatefulWidget {
  const CaregiverConsentScreen({
    super.key,
    this.caregiverDisplayName,
    this.caregiverRole,
    this.previewMode = true,
    this.onEnableSharing,
    this.onRevokeConfirmed,
  });

  /// Live grant label from Settings. Ignored for Heather unless passed in.
  final String? caregiverDisplayName;

  /// Optional role shown as `Connected to Name (Role)` when a name is set.
  final String? caregiverRole;

  /// Preview defaults for isolated widgets. Settings production passes `false`.
  final bool previewMode;

  final VoidCallback? onEnableSharing;
  final VoidCallback? onRevokeConfirmed;

  static const Key screenKey = Key('caregiver_consent_screen');
  static const Key bannerKey = Key('caregiver_consent_banner');
  static const Key shieldKey = Key('caregiver_consent_shield');
  static const Key masterSwitchKey = Key('caregiver_consent_master_switch');
  static const Key revokeKey = Key('caregiver_consent_revoke');
  static const Key moodRowKey = Key('caregiver_consent_row_mood');
  static const Key alertsRowKey = Key('caregiver_consent_row_alerts');
  static const Key checkInsRowKey = Key('caregiver_consent_row_checkins');
  static const Key revokeDialogKey = Key('caregiver_consent_revoke_dialog');

  @override
  State<CaregiverConsentScreen> createState() => _CaregiverConsentScreenState();
}

class _CaregiverConsentScreenState extends State<CaregiverConsentScreen> {
  // Preview (default) starts sharing on; production Settings passes false.
  bool _isSharingEnabled = false;
  // Local UI only — these switches do not grant mood, crisis, or check-in sharing.
  bool _shareMoodTrends = false;
  bool _shareEmergencyAlerts = false;
  bool _allowCheckInRequests = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _isSharingEnabled = true;
      _shareMoodTrends = true;
      _shareEmergencyAlerts = true;
      _allowCheckInRequests = false;
    }
  }

  String get _masterSubtitle {
    if (!_isSharingEnabled) return CaregiverConsentCopy.statusOff;
    if (widget.previewMode) {
      return CaregiverConsentCopy.connectedStatus(
        caregiverDisplayName: widget.caregiverDisplayName ??
            CaregiverConsentCopy.previewConnectedName,
        caregiverRole:
            widget.caregiverRole ?? CaregiverConsentCopy.previewConnectedRole,
      );
    }
    return CaregiverConsentCopy.connectedStatus(
      caregiverDisplayName: widget.caregiverDisplayName,
      caregiverRole: widget.caregiverRole,
    );
  }

  void _onMasterChanged(bool enable) {
    setState(() => _isSharingEnabled = enable);
    if (enable) widget.onEnableSharing?.call();
  }

  void _showRevokeConfirmationDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          key: CaregiverConsentScreen.revokeDialogKey,
          title: const Text(CaregiverConsentCopy.revokeConfirmTitle),
          content: Text(
            CaregiverConsentCopy.revokeConfirmBodyFor(
              previewMode: widget.previewMode,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(CaregiverConsentCopy.revokeCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () {
                setState(() {
                  _isSharingEnabled = false;
                  _shareMoodTrends = false;
                  _shareEmergencyAlerts = false;
                  _allowCheckInRequests = false;
                });
                widget.onRevokeConfirmed?.call();
                Navigator.of(dialogContext).pop();
              },
              child: const Text(CaregiverConsentCopy.revokeConfirmAction),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(CaregiverConsentCopy.screenTitle)),
      body: SafeArea(
        child: ListView(
          key: CaregiverConsentScreen.screenKey,
          padding: const EdgeInsets.all(24.0),
          children: [
            Card(
              key: CaregiverConsentScreen.bannerKey,
              elevation: 0,
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      key: CaregiverConsentScreen.shieldKey,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        CaregiverConsentCopy.banner,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              key: CaregiverConsentScreen.masterSwitchKey,
              value: _isSharingEnabled,
              onChanged: _onMasterChanged,
              secondary: Icon(
                Icons.family_restroom,
                color: _isSharingEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                CaregiverConsentCopy.masterTitle,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _masterSubtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: _isSharingEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 32),
            Text(
              CaregiverConsentCopy.sharingPermissions,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: CaregiverConsentScreen.moodRowKey,
              value: _isSharingEnabled && _shareMoodTrends,
              onChanged: _isSharingEnabled
                  ? (value) => setState(() => _shareMoodTrends = value)
                  : null,
              title: const Text(CaregiverConsentCopy.moodTitle),
              subtitle: const Text(CaregiverConsentCopy.moodBody),
            ),
            SwitchListTile(
              key: CaregiverConsentScreen.alertsRowKey,
              value: _isSharingEnabled && _shareEmergencyAlerts,
              onChanged: _isSharingEnabled
                  ? (value) => setState(() => _shareEmergencyAlerts = value)
                  : null,
              title: const Text(CaregiverConsentCopy.alertsTitle),
              subtitle: const Text(CaregiverConsentCopy.alertsBody),
            ),
            SwitchListTile(
              key: CaregiverConsentScreen.checkInsRowKey,
              value: _isSharingEnabled && _allowCheckInRequests,
              onChanged: _isSharingEnabled
                  ? (value) => setState(() => _allowCheckInRequests = value)
                  : null,
              title: const Text(CaregiverConsentCopy.checkInsTitle),
              subtitle: const Text(CaregiverConsentCopy.checkInsBody),
            ),
            const SizedBox(height: 40),
            if (_isSharingEnabled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: CaregiverConsentScreen.revokeKey,
                  onPressed: _showRevokeConfirmationDialog,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text(CaregiverConsentCopy.revokeCta),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
