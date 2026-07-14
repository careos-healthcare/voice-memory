import 'physical_device_smoke_proof_copy.dart';

/// Physical device smoke proof — iPhone/iPad release checklist only.
abstract final class PhysicalDeviceSmokeProof {
  PhysicalDeviceSmokeProof._();

  static const checkCount = 19;

  static PhysicalDeviceSmokeProofResult build(
    PhysicalDeviceSmokeProofInput input,
  ) {
    final checks = _buildChecks(input);
    final decision = _resolveDecision(checks);
    return PhysicalDeviceSmokeProofResult(
      decision: decision,
      message: _messageFor(decision),
      checks: checks,
      earliestBlocker: checks
          .where((check) => check.status == PhysicalDeviceSmokeProofStatus.fail)
          .map((check) => check.id)
          .firstOrNull,
      allPassed: decision == PhysicalDeviceSmokeProofDecision.proved,
    );
  }

  static PhysicalDeviceSmokeProofReport report(
    PhysicalDeviceSmokeProofResult result,
  ) =>
      PhysicalDeviceSmokeProofReport(
        headline: PhysicalDeviceSmokeProofCopy.headline,
        body: PhysicalDeviceSmokeProofCopy.body,
        manualNote: PhysicalDeviceSmokeProofCopy.manualNote,
        guardrail: PhysicalDeviceSmokeProofCopy.guardrail,
        result: result,
      );

  static bool detectAppNameArchiveMe(String infoPlistSource) =>
      infoPlistSource.contains('<key>CFBundleDisplayName</key>') &&
      infoPlistSource.contains('<string>ArchiveMe</string>');

  static bool detectLaunchScreenPresent(String launchScreenStoryboardSource) =>
      launchScreenStoryboardSource.contains('launchScreen="YES"') ||
      launchScreenStoryboardSource.contains('LaunchImage');

  static bool detectMicPermissionAcceptCopy(String micPermissionCopySource) =>
      micPermissionCopySource.contains('requestMicrophoneCta');

  static bool detectMicPermissionDenyCopy(String micPermissionCopySource) =>
      micPermissionCopySource.contains('typeInsteadCta') &&
      micPermissionCopySource.contains('deniedBody');

  static bool detectTypedSavePath(String visibleArchiveProofCopySource) =>
      visibleArchiveProofCopySource.contains('typeInsteadCta');

  static bool detectVoiceSavePath(String recordFramingCopySource) =>
      recordFramingCopySource.contains('Save one real moment') ||
      recordFramingCopySource.contains('Record one real moment');

  static bool detectTranscriptCorrectionPath(
    String transcriptCorrectionCopySource,
  ) =>
      transcriptCorrectionCopySource.contains('Correct transcript');

  static bool detectFirstProofThreshold(String archiveEvidenceGateSource) =>
      archiveEvidenceGateSource.contains('static const minProofEntryCount = 3;');

  static bool detectPostSaveReinforcementPath(
    String postSaveReinforcementCopySource,
  ) =>
      postSaveReinforcementCopySource
          .contains('PostSaveReinforcementPlacementCopy');

  static bool detectProScreenRoutes(String appRouterSource) =>
      appRouterSource.contains("path: '/pro-preview'") ||
      appRouterSource.contains('PaywallScreen');

  static bool detectPrivacyTermsSupportRoutes(String appRouterSource) =>
      appRouterSource.contains("path: '/privacy'") &&
      appRouterSource.contains("path: '/terms'") &&
      appRouterSource.contains("path: '/support-feedback'");

  static bool detectRestorePath(String securitySettingsSource) =>
      securitySettingsSource.contains("Key('security_restore_purchases')");

  static bool detectPurchaseUnavailableCopy(String proValueCopySource) =>
      proValueCopySource.contains('purchaseUnavailableNote') &&
      proValueCopySource.contains('Purchases are not available yet');

  static bool detectOfflineLaunchRoute(String appRouterSource) =>
      appRouterSource.contains("path: '/offline-sync-verify'");

  static bool detectLogPrivacyPolicy(String recordPipelineLogSource) {
    final lower = recordPipelineLogSource.toLowerCase();
    if (lower.contains('log(transcript') ||
        lower.contains("log('transcript:") ||
        lower.contains('log("transcript:')) {
      return false;
    }
    return lower.contains('transcript length=') &&
        lower.contains('display text length=');
  }

  static PhysicalDeviceSmokeProofInput fromRepoSignals({
    required String infoPlistSource,
    required String launchScreenStoryboardSource,
    required String micPermissionCopySource,
    required String visibleArchiveProofCopySource,
    required String recordFramingCopySource,
    required String transcriptCorrectionCopySource,
    required String archiveEvidenceGateSource,
    required String postSaveReinforcementCopySource,
    required String appRouterSource,
    required String securitySettingsSource,
    required String proValueCopySource,
    required String recordPipelineLogSource,
    bool? freshInstallOpens,
    bool? launchScreenOk,
    bool? micPermissionAcceptPath,
    bool? micPermissionDenyPath,
    bool? typedSave,
    bool? voiceSave,
    bool? transcriptAppears,
    bool? postSaveReinforcementAppears,
    bool? firstProofPath,
    bool? correctionPath,
    bool? proScreenOpens,
    bool? revenueCatProductLoad,
    bool? restorePathOpens,
    bool? offlineLaunchSafe,
    bool? noCrash,
  }) =>
      PhysicalDeviceSmokeProofInput(
        freshInstallOpens: freshInstallOpens,
        appNameArchiveMe: detectAppNameArchiveMe(infoPlistSource),
        launchScreenOk: launchScreenOk ??
            detectLaunchScreenPresent(launchScreenStoryboardSource),
        micPermissionAcceptPath: micPermissionAcceptPath ??
            (detectMicPermissionAcceptCopy(micPermissionCopySource)
                ? null
                : false),
        micPermissionDenyPath: micPermissionDenyPath ??
            (detectMicPermissionDenyCopy(micPermissionCopySource) ? null : false),
        typedSave: typedSave ??
            (detectTypedSavePath(visibleArchiveProofCopySource) ? null : false),
        voiceSave: voiceSave ??
            (detectVoiceSavePath(recordFramingCopySource) ? null : false),
        transcriptAppears: transcriptAppears,
        postSaveReinforcementAppears: postSaveReinforcementAppears ??
            (detectPostSaveReinforcementPath(postSaveReinforcementCopySource)
                ? null
                : false),
        firstProofPath: firstProofPath ??
            (detectFirstProofThreshold(archiveEvidenceGateSource) ? null : false),
        correctionPath: correctionPath ??
            (detectTranscriptCorrectionPath(transcriptCorrectionCopySource)
                ? null
                : false),
        proScreenOpens: proScreenOpens ??
            (detectProScreenRoutes(appRouterSource) ? null : false),
        revenueCatProductLoad: revenueCatProductLoad,
        purchaseUnavailableCopySafe:
            detectPurchaseUnavailableCopy(proValueCopySource),
        restorePathOpens: restorePathOpens ??
            (detectRestorePath(securitySettingsSource) ? null : false),
        privacyTermsSupportRoutesOpen:
            detectPrivacyTermsSupportRoutes(appRouterSource),
        offlineLaunchSafe: offlineLaunchSafe ??
            (detectOfflineLaunchRoute(appRouterSource) ? null : false),
        noCrash: noCrash,
        noPrivateTextLeakedInLogs:
            detectLogPrivacyPolicy(recordPipelineLogSource),
      );

  static List<PhysicalDeviceSmokeProofCheck> _buildChecks(
    PhysicalDeviceSmokeProofInput input,
  ) {
    PhysicalDeviceSmokeProofStatus triState(bool? value) {
      if (value == null) return PhysicalDeviceSmokeProofStatus.pending;
      return value
          ? PhysicalDeviceSmokeProofStatus.pass
          : PhysicalDeviceSmokeProofStatus.fail;
    }

    PhysicalDeviceSmokeProofStatus gatedTriState({
      required bool prerequisite,
      required bool? value,
    }) {
      if (!prerequisite) return PhysicalDeviceSmokeProofStatus.blocked;
      return triState(value);
    }

    PhysicalDeviceSmokeProofStatus repoBool(bool value) =>
        value
            ? PhysicalDeviceSmokeProofStatus.pass
            : PhysicalDeviceSmokeProofStatus.fail;

    final installOk = input.freshInstallOpens != false;
    final nameOk = installOk && input.appNameArchiveMe;
    final launchOk = nameOk && input.launchScreenOk != false;
    final micAcceptOk = launchOk && input.micPermissionAcceptPath != false;
    final micDenyOk = launchOk && input.micPermissionDenyPath != false;
    final typedOk = micDenyOk && input.typedSave != false;
    final voiceOk = typedOk && input.voiceSave != false;
    final transcriptOk = voiceOk && input.transcriptAppears != false;
    final reinforcementOk =
        transcriptOk && input.postSaveReinforcementAppears != false;
    final proofOk = reinforcementOk && input.firstProofPath != false;
    final correctionOk = proofOk && input.correctionPath != false;
    final proOk = correctionOk && input.proScreenOpens != false;
    final revenueCatOk = proOk && input.revenueCatProductLoad != false;
    final restoreOk =
        revenueCatOk && input.purchaseUnavailableCopySafe && input.restorePathOpens != false;

    return [
      _check(
        id: PhysicalDeviceSmokeProofCheckId.freshInstallOpens,
        status: triState(input.freshInstallOpens),
        detailLabel: _detailFor(triState(input.freshInstallOpens)),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.appNameArchiveMe,
        status: gatedTriState(prerequisite: installOk, value: input.appNameArchiveMe),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: installOk, value: input.appNameArchiveMe),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.launchScreenOk,
        status: gatedTriState(
          prerequisite: nameOk,
          value: input.launchScreenOk,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: nameOk, value: input.launchScreenOk),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.micPermissionAcceptPath,
        status: gatedTriState(
          prerequisite: launchOk,
          value: input.micPermissionAcceptPath,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: launchOk,
            value: input.micPermissionAcceptPath,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.micPermissionDenyPath,
        status: gatedTriState(
          prerequisite: launchOk,
          value: input.micPermissionDenyPath,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: launchOk,
            value: input.micPermissionDenyPath,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.typedSave,
        status: gatedTriState(prerequisite: micDenyOk, value: input.typedSave),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: micDenyOk, value: input.typedSave),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.voiceSave,
        status: gatedTriState(prerequisite: typedOk, value: input.voiceSave),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: typedOk, value: input.voiceSave),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.transcriptAppears,
        status: gatedTriState(
          prerequisite: voiceOk,
          value: input.transcriptAppears,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: voiceOk, value: input.transcriptAppears),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.postSaveReinforcementAppears,
        status: gatedTriState(
          prerequisite: transcriptOk,
          value: input.postSaveReinforcementAppears,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: transcriptOk,
            value: input.postSaveReinforcementAppears,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.firstProofPath,
        status: gatedTriState(
          prerequisite: reinforcementOk,
          value: input.firstProofPath,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: reinforcementOk,
            value: input.firstProofPath,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.correctionPath,
        status: gatedTriState(
          prerequisite: proofOk,
          value: input.correctionPath,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: proofOk, value: input.correctionPath),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.proScreenOpens,
        status: gatedTriState(
          prerequisite: correctionOk,
          value: input.proScreenOpens,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: correctionOk, value: input.proScreenOpens),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.revenueCatProductLoad,
        status: gatedTriState(
          prerequisite: proOk,
          value: input.revenueCatProductLoad,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: proOk, value: input.revenueCatProductLoad),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.purchaseUnavailableCopySafe,
        status: gatedTriState(
          prerequisite: proOk,
          value: input.purchaseUnavailableCopySafe,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: proOk,
            value: input.purchaseUnavailableCopySafe,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.restorePathOpens,
        status: gatedTriState(
          prerequisite: revenueCatOk && input.purchaseUnavailableCopySafe,
          value: input.restorePathOpens,
        ),
        detailLabel: _detailFor(
          gatedTriState(
            prerequisite: revenueCatOk && input.purchaseUnavailableCopySafe,
            value: input.restorePathOpens,
          ),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.privacyTermsSupportRoutesOpen,
        status: repoBool(input.privacyTermsSupportRoutesOpen),
        detailLabel: input.privacyTermsSupportRoutesOpen
            ? PhysicalDeviceSmokeProofCopy.detailPass
            : PhysicalDeviceSmokeProofCopy.detailFail,
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.offlineLaunchSafe,
        status: gatedTriState(
          prerequisite: restoreOk,
          value: input.offlineLaunchSafe,
        ),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: restoreOk, value: input.offlineLaunchSafe),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.noCrash,
        status: gatedTriState(prerequisite: installOk, value: input.noCrash),
        detailLabel: _detailFor(
          gatedTriState(prerequisite: installOk, value: input.noCrash),
        ),
      ),
      _check(
        id: PhysicalDeviceSmokeProofCheckId.noPrivateTextLeakedInLogs,
        status: repoBool(input.noPrivateTextLeakedInLogs),
        detailLabel: input.noPrivateTextLeakedInLogs
            ? PhysicalDeviceSmokeProofCopy.detailPass
            : PhysicalDeviceSmokeProofCopy.detailFail,
      ),
    ];
  }

  static PhysicalDeviceSmokeProofDecision _resolveDecision(
    List<PhysicalDeviceSmokeProofCheck> checks,
  ) {
    if (checks.any(
      (check) => check.status == PhysicalDeviceSmokeProofStatus.fail,
    )) {
      return PhysicalDeviceSmokeProofDecision.blocked;
    }

    if (checks.every(
      (check) => check.status == PhysicalDeviceSmokeProofStatus.pass,
    )) {
      return PhysicalDeviceSmokeProofDecision.proved;
    }

    return PhysicalDeviceSmokeProofDecision.manualRequired;
  }

  static String _messageFor(PhysicalDeviceSmokeProofDecision decision) =>
      switch (decision) {
        PhysicalDeviceSmokeProofDecision.proved =>
          PhysicalDeviceSmokeProofCopy.provedLine,
        PhysicalDeviceSmokeProofDecision.manualRequired =>
          PhysicalDeviceSmokeProofCopy.manualRequiredLine,
        PhysicalDeviceSmokeProofDecision.blocked =>
          PhysicalDeviceSmokeProofCopy.blockedLine,
      };

  static String _detailFor(PhysicalDeviceSmokeProofStatus status) =>
      switch (status) {
        PhysicalDeviceSmokeProofStatus.pass =>
          PhysicalDeviceSmokeProofCopy.detailPass,
        PhysicalDeviceSmokeProofStatus.fail =>
          PhysicalDeviceSmokeProofCopy.detailFail,
        PhysicalDeviceSmokeProofStatus.pending =>
          PhysicalDeviceSmokeProofCopy.detailPending,
        PhysicalDeviceSmokeProofStatus.blocked =>
          PhysicalDeviceSmokeProofCopy.detailBlocked,
      };

  static PhysicalDeviceSmokeProofCheck _check({
    required PhysicalDeviceSmokeProofCheckId id,
    required PhysicalDeviceSmokeProofStatus status,
    required String detailLabel,
  }) =>
      PhysicalDeviceSmokeProofCheck(
        id: id,
        label: PhysicalDeviceSmokeProofCopy.labelFor(id),
        status: status,
        detailLabel: detailLabel,
      );
}

class PhysicalDeviceSmokeProofInput {
  const PhysicalDeviceSmokeProofInput({
    this.freshInstallOpens,
    this.appNameArchiveMe = false,
    this.launchScreenOk,
    this.micPermissionAcceptPath,
    this.micPermissionDenyPath,
    this.typedSave,
    this.voiceSave,
    this.transcriptAppears,
    this.postSaveReinforcementAppears,
    this.firstProofPath,
    this.correctionPath,
    this.proScreenOpens,
    this.revenueCatProductLoad,
    this.purchaseUnavailableCopySafe = false,
    this.restorePathOpens,
    this.privacyTermsSupportRoutesOpen = false,
    this.offlineLaunchSafe,
    this.noCrash,
    this.noPrivateTextLeakedInLogs = false,
  });

  final bool? freshInstallOpens;
  final bool appNameArchiveMe;
  final bool? launchScreenOk;
  final bool? micPermissionAcceptPath;
  final bool? micPermissionDenyPath;
  final bool? typedSave;
  final bool? voiceSave;
  final bool? transcriptAppears;
  final bool? postSaveReinforcementAppears;
  final bool? firstProofPath;
  final bool? correctionPath;
  final bool? proScreenOpens;
  final bool? revenueCatProductLoad;
  final bool purchaseUnavailableCopySafe;
  final bool? restorePathOpens;
  final bool privacyTermsSupportRoutesOpen;
  final bool? offlineLaunchSafe;
  final bool? noCrash;
  final bool noPrivateTextLeakedInLogs;
}

class PhysicalDeviceSmokeProofCheck {
  const PhysicalDeviceSmokeProofCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PhysicalDeviceSmokeProofCheckId id;
  final String label;
  final PhysicalDeviceSmokeProofStatus status;
  final String detailLabel;
}

class PhysicalDeviceSmokeProofResult {
  const PhysicalDeviceSmokeProofResult({
    required this.decision,
    required this.message,
    required this.checks,
    required this.earliestBlocker,
    required this.allPassed,
  });

  final PhysicalDeviceSmokeProofDecision decision;
  final String message;
  final List<PhysicalDeviceSmokeProofCheck> checks;
  final PhysicalDeviceSmokeProofCheckId? earliestBlocker;
  final bool allPassed;
}

class PhysicalDeviceSmokeProofReport {
  const PhysicalDeviceSmokeProofReport({
    required this.headline,
    required this.body,
    required this.manualNote,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String manualNote;
  final String guardrail;
  final PhysicalDeviceSmokeProofResult result;
}
