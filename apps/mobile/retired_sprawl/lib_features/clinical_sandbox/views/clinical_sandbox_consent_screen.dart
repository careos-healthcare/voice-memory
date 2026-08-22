import 'package:archiveme_mobile/features/clinical_sandbox/config/clinical_sandbox_feature_flags.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/gates/clinical_consent_gate.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/presentation/clinical_consent_copy.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/runtime/clinical_sandbox_runtime.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/views/clinical_consent_disclaimer_view.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Regulatory sandbox entry — consent gate wrapper for clinical analysis.
class ClinicalSandboxConsentScreen extends StatelessWidget {
  const ClinicalSandboxConsentScreen({
    required this.gate, super.key,
  });

  final ClinicalConsentGate gate;

  @override
  Widget build(BuildContext context) {
    if (!ClinicalSandboxFeatureFlags.isEnabled) {
      return PushedScreenShell(
        title: ClinicalConsentCopy.screenTitle,
        body: Center(
          child: Text(
            'Clinical sandbox is disabled in this build.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return PushedScreenShell(
      title: ClinicalConsentCopy.screenTitle,
      body: ClinicalConsentDisclaimerView(
        gate: gate,
        onCompleted: () => context.pop(true),
        onCancelled: () => context.pop(false),
      ),
    );
  }
}

/// Returns true when clinical analysis is permitted after this flow.
Future<bool> ensureClinicalSandboxConsent(BuildContext context) async {
  if (!ClinicalSandboxFeatureFlags.isEnabled) return false;
  if (ClinicalSandboxRuntime.mayRunClinicalAnalysis) return true;

  final gate = ClinicalSandboxRuntime.consentGate;
  if (gate == null) return false;

  final result = await context.push<bool>(
    '/clinical-sandbox-consent',
  );
  return result == true && ClinicalSandboxRuntime.mayRunClinicalAnalysis;
}