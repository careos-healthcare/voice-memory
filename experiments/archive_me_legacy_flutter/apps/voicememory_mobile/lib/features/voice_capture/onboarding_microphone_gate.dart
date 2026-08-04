import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/record/microphone_permission_blocked_panel.dart';
import '../../widgets/record/microphone_soft_prompt.dart';
import 'microphone_permission_copy.dart';
import 'microphone_permission_gateway.dart';
import 'onboarding_microphone_state.dart';

enum OnboardingMicrophoneView { loading, softPrompt, recovery, active }

abstract class OnboardingMicrophoneViewResolver {
  OnboardingMicrophoneViewResolver._();

  static OnboardingMicrophoneView fromLocalState(OnboardingMicState state) {
    return switch (state) {
      OnboardingMicState.notPrompted || OnboardingMicState.softPromptAccepted =>
        OnboardingMicrophoneView.softPrompt,
      OnboardingMicState.granted => OnboardingMicrophoneView.active,
      OnboardingMicState.denied ||
      OnboardingMicState.permanentlyDenied => OnboardingMicrophoneView.recovery,
    };
  }
}

/// Reusable onboarding/First Three Journey microphone permission boundary.
class OnboardingMicrophoneGate extends StatefulWidget {
  const OnboardingMicrophoneGate({
    super.key,
    required this.store,
    required this.child,
    this.gateway,
    this.openSettings,
    this.onTypeInstead,
  });

  final OnboardingMicStateStore store;
  final MicrophonePermissionGateway? gateway;
  final Widget child;
  final Future<bool> Function()? openSettings;
  final Future<void> Function()? onTypeInstead;

  @override
  State<OnboardingMicrophoneGate> createState() =>
      _OnboardingMicrophoneGateState();
}

class _OnboardingMicrophoneGateState extends State<OnboardingMicrophoneGate>
    with WidgetsBindingObserver {
  late final MicrophonePermissionGateway _gateway =
      widget.gateway ?? PermissionHandlerMicrophoneGateway();
  OnboardingMicrophoneView _view = OnboardingMicrophoneView.loading;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreOnResume());
    }
  }

  Future<void> _load() async {
    final status = await _gateway.status;
    if (status.isGranted) {
      await widget.store.write(OnboardingMicState.granted);
      _setView(OnboardingMicrophoneView.active);
      return;
    }
    if (_requiresSettings(status)) {
      await widget.store.write(OnboardingMicState.permanentlyDenied);
      _setView(OnboardingMicrophoneView.recovery);
      return;
    }
    final local = await widget.store.read();
    _setView(OnboardingMicrophoneViewResolver.fromLocalState(local));
  }

  Future<void> _accept() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    await widget.store.write(OnboardingMicState.softPromptAccepted);
    final status = await _gateway.request();
    await widget.store.recordPermissionStatus(status);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _view = status.isGranted
          ? OnboardingMicrophoneView.active
          : OnboardingMicrophoneView.recovery;
    });
  }

  Future<void> _restoreOnResume() async {
    final status = await _gateway.status;
    if (!status.isGranted) return;
    final wasRecovery = _view == OnboardingMicrophoneView.recovery;
    await widget.store.write(OnboardingMicState.granted);
    _setView(OnboardingMicrophoneView.active);
    if (!mounted || !wasRecovery) return;
    unawaited(HapticFeedback.lightImpact());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(MicrophonePermissionCopy.connectedMessage),
        ),
      );
  }

  void _setView(OnboardingMicrophoneView view) {
    if (mounted) setState(() => _view = view);
  }

  static bool _requiresSettings(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted || status.isLimited;

  @override
  Widget build(BuildContext context) {
    final content = switch (_view) {
      OnboardingMicrophoneView.loading => const SizedBox.shrink(
        key: Key('microphone_permission_loading'),
      ),
      OnboardingMicrophoneView.softPrompt => IgnorePointer(
        ignoring: _requesting,
        child: MicrophoneSoftPrompt(
          onContinue: () => unawaited(_accept()),
          onNotNow: () {},
        ),
      ),
      OnboardingMicrophoneView.recovery => MicAccessRecoveryCard(
        onOpenSettings: () {
          unawaited((widget.openSettings ?? openAppSettings)());
        },
        onTypeInstead: widget.onTypeInstead ?? () async {},
      ),
      OnboardingMicrophoneView.active => widget.child,
    };
    return AnimatedSwitcher(
      key: const Key('onboarding_microphone_animated_switcher'),
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: content,
    );
  }
}
