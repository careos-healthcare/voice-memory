import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:flutter/material.dart';

/// Standalone caregiver-consent panel: local [setState] only.
///
/// Production Settings must pass [previewMode] `false` and a real
/// [caregiverDisplayName] only when a grant exists. [previewMode] `true`
/// fills Heather / Primary Caregiver for isolated previews and tests.
class CaregiverConsentScreen extends StatefulWidget {
  const CaregiverConsentScreen({
    super.key,
    this.caregiverDisplayName,
    this.caregiverRole,
    this.previewMode = false,
    this.onEnableSharing,
    this.onRevokeConfirmed,
  });

  /// Live grant label from Settings. Ignored for Heather unless passed in.
  final String? caregiverDisplayName;

  /// Optional role shown as `Connected to Name (Role)` when a name is set.
  final String? caregiverRole;

  /// When true, master-on uses Heather / Primary Caregiver if no name is set.
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
  bool _sharingEnabled = false;
  // Local UI only — these switches do not grant mood, crisis, or check-in sharing.
  bool _shareMood = false;
  bool _shareEmergencyAlerts = false;
  bool _allowCheckInRequests = false;

  String get _masterSubtitle {
    if (!_sharingEnabled) return CaregiverConsentCopy.statusOff;
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
    setState(() => _sharingEnabled = enable);
    if (enable) widget.onEnableSharing?.call();
  }

  Future<void> _confirmAndRevoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: CaregiverConsentScreen.revokeDialogKey,
        title: const Text(CaregiverConsentCopy.revokeConfirmTitle),
        content: const Text(CaregiverConsentCopy.revokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(CaregiverConsentCopy.revokeCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(CaregiverConsentCopy.revokeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _sharingEnabled = false;
      _shareMood = false;
      _shareEmergencyAlerts = false;
      _allowCheckInRequests = false;
    });
    widget.onRevokeConfirmed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(CaregiverConsentCopy.screenTitle)),
      body: ListView(
        key: CaregiverConsentScreen.screenKey,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            key: CaregiverConsentScreen.bannerKey,
            elevation: 0,
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    key: CaregiverConsentScreen.shieldKey,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text(CaregiverConsentCopy.banner)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: CaregiverConsentScreen.masterSwitchKey,
            secondary: const Icon(Icons.family_restroom),
            title: const Text(CaregiverConsentCopy.masterTitle),
            subtitle: Text(_masterSubtitle),
            value: _sharingEnabled,
            onChanged: _onMasterChanged,
          ),
          SwitchListTile(
            key: CaregiverConsentScreen.moodRowKey,
            title: const Text(CaregiverConsentCopy.moodTitle),
            subtitle: const Text(CaregiverConsentCopy.moodBody),
            value: _shareMood,
            onChanged: _sharingEnabled
                ? (value) => setState(() => _shareMood = value)
                : null,
          ),
          SwitchListTile(
            key: CaregiverConsentScreen.alertsRowKey,
            title: const Text(CaregiverConsentCopy.alertsTitle),
            subtitle: const Text(CaregiverConsentCopy.alertsBody),
            value: _shareEmergencyAlerts,
            onChanged: _sharingEnabled
                ? (value) => setState(() => _shareEmergencyAlerts = value)
                : null,
          ),
          SwitchListTile(
            key: CaregiverConsentScreen.checkInsRowKey,
            title: const Text(CaregiverConsentCopy.checkInsTitle),
            subtitle: const Text(CaregiverConsentCopy.checkInsBody),
            value: _allowCheckInRequests,
            onChanged: _sharingEnabled
                ? (value) => setState(() => _allowCheckInRequests = value)
                : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: CaregiverConsentScreen.revokeKey,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                minimumSize: const Size(0, 48),
              ),
              onPressed: _confirmAndRevoke,
              child: const Text(CaregiverConsentCopy.revokeCta),
            ),
          ),
        ],
      ),
    );
  }
}
