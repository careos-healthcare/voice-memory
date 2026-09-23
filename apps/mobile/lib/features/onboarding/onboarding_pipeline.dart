import 'dart:async';

import 'package:archiveme_mobile/features/monetization/ui/paywall_view.dart';
import 'package:archiveme_mobile/features/onboarding/onboarding_router.dart';
import 'package:archiveme_mobile/features/onboarding/sample_graph_explorer_screen.dart';
import 'package:archiveme_mobile/features/onboarding/trial_completion_store.dart';
import 'package:archiveme_mobile/features/onboarding/trial_voice_entry_screen.dart';
import 'package:archiveme_mobile/features/sample_vault/interactive_vault_demo_screen.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hosts the first-run sequence from value demonstration through the paywall.
class OnboardingPipeline extends StatefulWidget {
  const OnboardingPipeline({
    super.key,
    this.store,
    this.paywall,
    this.onFinished,
    this.transcribe,
  });

  final TrialCompletionStore? store;
  final Widget? paywall;
  final VoidCallback? onFinished;
  final Future<String> Function()? transcribe;

  @override
  State<OnboardingPipeline> createState() => _OnboardingPipelineState();
}

class _OnboardingPipelineState extends State<OnboardingPipeline> {
  late final TrialCompletionStore _store;
  OnboardingStep _step = OnboardingStep.valueWelcome;
  var _hasCompletedTrial = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ??
        (AppServices.isInitialized
            ? PrefsTrialCompletionStore(AppServices.instance.prefs)
            : MemoryTrialCompletionStore());
    unawaited(_load());
  }

  Future<void> _load() async {
    final completed = await _store.hasCompletedTrial();
    if (!mounted) return;
    setState(() {
      _hasCompletedTrial = completed;
      _ready = true;
    });
  }

  void _goNext({bool saveBeyondTrialBounds = false}) {
    final next = OnboardingRouter.next(
      current: _step,
      hasCompletedTrial: _hasCompletedTrial,
      saveBeyondTrialBounds: saveBeyondTrialBounds,
    );
    if (next == null) {
      unawaited(_finish());
      return;
    }
    setState(() => _step = next);
  }

  void _markTrialCompleted() {
    if (_hasCompletedTrial) return;
    _hasCompletedTrial = true;
    unawaited(_store.markTrialCompleted());
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
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: _ready ? _page() : const SizedBox.shrink(),
      ),
    );
  }

  Widget _page() {
    return switch (_step) {
      OnboardingStep.valueWelcome => _ValuePage(
        title: 'Save the moment. See what returns.',
        body:
            'A short trial lets you speak a moment and hear it back before anything is saved.',
        onContinue: _goNext,
      ),
      OnboardingStep.valueTrust => _ValuePage(
        title: 'Your words stay on this device',
        body:
            'This trial does not ask for an account. Saving a moment into the archive comes later.',
        onContinue: _goNext,
      ),
      OnboardingStep.trialVoice => TrialVoiceEntryScreen(
        transcribe: widget.transcribe,
        onTrialCompleted: _markTrialCompleted,
        onContinue: _goNext,
        onSaveBeyondBounds: () => _goNext(saveBeyondTrialBounds: true),
      ),
      OnboardingStep.sampleGraph => SampleGraphExplorerScreen(
        onContinue: _goNext,
      ),
      OnboardingStep.vaultDemo => InteractiveVaultDemoScreen(
        onUnlock: () => setState(() => _step = OnboardingStep.paywall),
      ),
      OnboardingStep.paywall => Column(
        children: [
          Expanded(
            child: widget.paywall ?? const PaywallView(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spacing6,
              0,
              AppTokens.spacing6,
              AppTokens.spacing4,
            ),
            child: TextButton(
              key: const Key('onboarding_paywall_continue'),
              onPressed: _finish,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    };
  }
}

class _ValuePage extends StatelessWidget {
  const _ValuePage({
    required this.title,
    required this.body,
    required this.onContinue,
  });

  final String title;
  final String body;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, key: const Key('onboarding_value_title'), style: AppTokens.section()),
          const SizedBox(height: AppTokens.spacing4),
          Text(body, style: AppTokens.body()),
          const Spacer(),
          FilledButton(
            key: const Key('onboarding_value_continue'),
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
