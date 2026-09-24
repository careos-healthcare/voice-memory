import 'dart:async';

import 'package:archiveme_mobile/features/monetization/revenuecat_initializer.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Microphone and storage checks used by the onboarding permission step.
class OnboardingPermissionClient {
  const OnboardingPermissionClient({
    required this.status,
    required this.request,
    required this.openSettings,
  });

  final Future<PermissionStatus> Function(Permission permission) status;
  final Future<PermissionStatus> Function(Permission permission) request;
  final Future<bool> Function() openSettings;

  static final live = OnboardingPermissionClient(
    status: (permission) => permission.status,
    request: (permission) => permission.request(),
    openSettings: openAppSettings,
  );
}

/// Three-page first run: privacy, permissions, then an open first entry.
class PrivacyOnboardingFlow extends StatefulWidget {
  const PrivacyOnboardingFlow({
    super.key,
    this.permissions,
    this.preparePurchases,
    this.onFinished,
  });

  final OnboardingPermissionClient? permissions;
  final Future<void> Function()? preparePurchases;
  final VoidCallback? onFinished;

  @override
  State<PrivacyOnboardingFlow> createState() => _PrivacyOnboardingFlowState();
}

class _PrivacyOnboardingFlowState extends State<PrivacyOnboardingFlow> {
  final _pages = PageController();
  var _page = 0;
  var _asking = false;
  var _settingsRequired = false;
  var _purchasesStarted = false;

  OnboardingPermissionClient get _permissions =>
      widget.permissions ?? OnboardingPermissionClient.live;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page == 1) {
      final allowed = await _requestCapturePermissions();
      if (!allowed || !mounted) return;
    }
    if (_page >= 2) {
      await _finish();
      return;
    }
    final target = _page + 1;
    await _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    setState(() => _page = target);
    if (target == 2) _startPurchases();
  }

  void _startPurchases() {
    if (_purchasesStarted) return;
    _purchasesStarted = true;
    final prepare =
        widget.preparePurchases ?? RevenueCatInitializer.ensureConfigured;
    unawaited(prepare());
  }

  Future<bool> _requestCapturePermissions() async {
    setState(() => _asking = true);
    try {
      const needed = [Permission.microphone, Permission.storage];
      final current = await Future.wait(needed.map(_permissions.status));
      if (current.any((status) => status.isPermanentlyDenied)) {
        setState(() => _settingsRequired = true);
        return false;
      }
      final decided = await Future.wait(needed.map(_permissions.request));
      final blocked = decided.any((status) => status.isPermanentlyDenied);
      if (blocked && mounted) setState(() => _settingsRequired = true);
      return !blocked;
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _finish() async {
    if (AppServices.isInitialized) {
      await AppServices.instance.prefs.setOnboardingCompleted(true);
    }
    onboardingGate.markComplete();
    final finished = widget.onFinished;
    if (finished != null) {
      finished();
      return;
    }
    if (!mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      context.go(RouteCatalog.recordHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy_onboarding_flow'),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OnboardingPage(
                    title: 'Your words stay on this device',
                    body:
                        'A recording and the reading of it happen on this phone. The first moment does not wait on an account or a network.',
                    actionLabel: 'Continue',
                    onAction: _asking ? null : _next,
                  ),
                  _OnboardingPage(
                    title: 'Microphone and storage',
                    body: _settingsRequired
                        ? 'Microphone or storage is turned off for this app. Open Settings to allow them, then come back to record.'
                        : 'The microphone saves a voice moment. Storage keeps that recording on this phone. The system prompt appears after you continue.',
                    actionLabel: _settingsRequired
                        ? 'Open Settings'
                        : 'Continue',
                    onAction: _asking
                        ? null
                        : () {
                            if (_settingsRequired) {
                              unawaited(_permissions.openSettings());
                              return;
                            }
                            unawaited(_next());
                          },
                  ),
                  _OnboardingPage(
                    title: 'Save your first moment',
                    body:
                        'You can record now. A trial is prepared quietly and does not hold this step.',
                    actionLabel: 'Start recording',
                    onAction: _next,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spacing4),
              child: Text('${_page + 1} of 3'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTokens.section()),
          const SizedBox(height: AppTokens.spacing4),
          Text(body, style: AppTokens.body()),
          const Spacer(),
          FilledButton(
            key: Key('onboarding_action_$actionLabel'),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
