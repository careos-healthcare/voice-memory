import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_error_message.dart';
import '../config/app_config.dart';
import '../config/developer_settings_gate.dart';
import '../widgets/debug_only_unavailable.dart';
import '../push/firebase_bootstrap.dart';
import '../push/firebase_options.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';

/// FCM push verification — developer gate only.
class NativePushVerificationScreen extends StatefulWidget {
  const NativePushVerificationScreen({super.key});

  @override
  State<NativePushVerificationScreen> createState() =>
      _NativePushVerificationScreenState();
}

class _NativePushVerificationScreenState
    extends State<NativePushVerificationScreen> {
  String? _message;
  String? _exportJson;
  bool _busy = false;

  bool get _debugDetails =>
      DeveloperSettingsGate.canShowInternalVerificationDetails;

  Future<void> _refresh() async {
    final fcm = AppServices.instance.fcm;
    final state = await AppServices.instance.nativePushStore.platformState(
      AppServices.instance.nativePushPlatform,
    );
    final lines = <String>[
      'Push configured: ${fcm.isConfigured}',
      'Permission: ${state.permissionGranted}',
      'Notification received: ${state.notificationReceived}',
      'Notification opened: ${state.notificationOpened}',
      'Archive destination: ${state.archiveDestinationVerified}',
      'Discover destination: ${state.discoverDestinationVerified}',
      'Record destination: ${state.recordDestinationVerified}',
      'Last route: ${fcm.lastPushRoute ?? "—"}',
    ];
    if (_debugDetails) {
      final deviceId = await AppServices.instance.deviceIds.getOrCreate();
      lines.insertAll(0, [
        'deviceId: $deviceId',
        'Firebase dart-define: ${FirebaseOptionsConfig.isConfigured ? "yes" : "no"}',
        'FCM token: ${fcm.fcmToken ?? "—"}',
      ]);
      lines.add(
        'Deep link: ${fcm.deepLink.lastExpectedRoute ?? "—"} → ${fcm.deepLink.lastActualRoute ?? "—"}',
      );
    }
    setState(() => _message = lines.join('\n'));
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    try {
      if (!AppConfig.isBackendConfigured) {
        setState(() {
          _busy = false;
          _message = cloudBackendUnavailableMessage;
        });
        return;
      }
      final ok = await AppServices.instance.nativePush.requestPermission();
      setState(() {
        _busy = false;
        _message = ok
            ? 'Permission granted — token registered with backend'
            : 'Permission denied';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _message = userFacingErrorMessage(e);
      });
    }
    await _refresh();
  }

  Future<void> _sendBackend(String route, String label) async {
    if (!AppConfig.isBackendConfigured) {
      setState(() {
        _message = cloudBackendUnavailableMessage;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await AppServices.instance.nativePush.sendBackendTestPush(
        targetRoute: route,
      );
      setState(() {
        _busy = false;
        _message = _debugDetails
            ? 'FCM sent ($label) — wait for notification on this device, then tap it.\n$result'
            : 'Test notification sent ($label). Check this device and tap the notification.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _message = userFacingErrorMessage(
          e,
          fallback: 'Could not send test notification.',
        );
      });
    }
  }

  Future<void> _export() async {
    if (!_debugDetails) return;
    setState(() => _busy = true);
    final json = await AppServices.instance.nativePushStore
        .exportEvidenceJson();
    await Clipboard.setData(ClipboardData(text: json));
    setState(() {
      _busy = false;
      _exportJson = json;
      _message =
          'Evidence copied — commit mobile/evidence/native_push_verification.json\n'
          'Run npm run validate:push-production from repo root.';
    });
  }

  @override
  void initState() {
    super.initState();
    if (DeveloperSettingsGate.canShowDeveloperSettings) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'Push verification');
    }

    final backendOk = AppConfig.isBackendConfigured;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Native push verify (FCM)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Physical device only. Backend sends real FCM — no local notifications. '
            'Complete archive, discover, and record destinations on this platform, '
            'then repeat on the other OS and merge JSON.',
            style: TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          if (!backendOk) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                color: Colors.orange.withValues(alpha: 0.08),
              ),
              child: Text(
                _debugDetails
                    ? '$cloudBackendUnavailableMessage\n\n'
                          'Physical devices require a reachable backend URL:\n'
                          'flutter run --dart-define=${AppConfig.apiBaseUrlDefineKey}=http://YOUR_LAN_IP:3000\n\n'
                          'Android emulator uses ${AppConfig.defaultAndroidEmulatorBaseUrl} automatically.'
                    : cloudBackendUnavailableMessage,
                style: const TextStyle(
                  color: AppTheme.foreground,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _message!,
              style: const TextStyle(color: AppTheme.foreground, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          _button('Refresh status', _refresh),
          _button('Request permission + register token', _requestPermission),
          _button(
            'Send Archive Push (backend)',
            () => _sendBackend('/archive-belief', 'Archive'),
          ),
          _button(
            'Send Discover Push (backend)',
            () => _sendBackend('/archive-belief', 'Archive'),
          ),
          _button(
            'Send Record Push (backend)',
            () => _sendBackend('/record', 'Record'),
          ),
          if (_debugDetails) ...[
            const SizedBox(height: 12),
            _button('Export evidence JSON', _export),
            if (_exportJson != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Preview',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _exportJson!,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'API: ${AppConfig.apiBaseUrlStatusLabel}\n'
              'Debug token: ${AppConfig.internalDebugToken.isNotEmpty ? "configured" : "not set"}\n'
              'FCM init: ${FirebaseBootstrap.isInitialized ? "Firebase ready" : "push disabled"}\n'
              'Expected defines: ${AppConfig.apiBaseUrlDefineKey}, FIREBASE_API_KEY, '
              'FIREBASE_APP_ID, FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      ),
    );
  }
}
