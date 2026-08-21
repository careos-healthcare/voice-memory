#!/usr/bin/env node
/**
 * Refactors recording_state_build.dart:
 * - Introduces _RecordUiFlags and switch dispatch entry point
 * - Replaces redundant `ui == RecordUiState.*` with `flags.is*`
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const buildPath = path.join(
  root,
  "lib/features/recording/recording_state_build.dart",
);

let src = fs.readFileSync(buildPath, "utf8");

const replacements = [
  [/ui == RecordUiState\.ready/g, "flags.isReady"],
  [/ui == RecordUiState\.recording/g, "flags.isRecording"],
  [/ui == RecordUiState\.processing/g, "flags.isProcessing"],
  [/ui == RecordUiState\.done/g, "flags.isDone"],
  [/ui == RecordUiState\.idle/g, "flags.isIdle"],
  [
    /ui == RecordUiState\.requestingPermission/g,
    "flags.isRequestingPermission",
  ],
  [
    /ui == RecordUiState\.permissionBlocked/g,
    "flags.isPermissionBlocked",
  ],
  [/ui == RecordUiState\.error/g, "flags.isError"],
  [
    /\(ui == RecordUiState\.ready \|\| ui == RecordUiState\.recording\)/g,
    "(flags.isReady || flags.isRecording)",
  ],
  [
    /ui == RecordUiState\.ready \|\|\s*\n\s*ui == RecordUiState\.idle/g,
    "flags.showFraming",
  ],
];

for (const [pattern, replacement] of replacements) {
  src = src.replace(pattern, replacement);
}

// Fix showFraming block that was multi-line
src = src.replace(
  /final showFraming =\s*\n\s*flags\.isReady \|\|\s*\n\s*flags\.isIdle \|\|\s*\n\s*flags\.isRequestingPermission \|\|\s*\n\s*flags\.isPermissionBlocked;/,
  "final showFraming = flags.showFraming;",
);

src = src.replace(
  /final canRecord =\s*\n\s*\(flags\.isReady \|\| flags\.isRecording\) &&\s*\n\s*!RecordMicrophonePermissionUi\.shouldHideBlockedPanelDuringRequest\(ui\);/,
  "final canRecord = flags.canRecord;",
);

const dispatchHeader = `part of '../../screens/record_screen.dart';

extension _RecordScreenStateBuild on _RecordScreenState {
  RecordUiState _resolveRecordBuildUi() {
    var ui = _ui;
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) ui = audit.ui;
    }
    return ui;
  }

  Widget _buildRecordScreen(BuildContext context) {
    ref.listen(recordingServiceProvider, (previous, next) {
      if (!mounted) return;
      final seconds = next.currentDuration.inSeconds;
      if (previous?.currentDuration == next.currentDuration) return;
      _recordingState.syncDurationSeconds(seconds);
      if (_ui == RecordUiState.recording &&
          RecordingDurationPolicy.shouldAutoStop(seconds)) {
        unawaited(_stopAndProcess(reachedDurationLimit: true));
      }
    });

    final ui = _resolveRecordBuildUi();
    return switch (ui) {
      RecordUiState.idle => _buildIdleState(context, ui),
      RecordUiState.requestingPermission =>
        _buildRequestingPermissionState(context, ui),
      RecordUiState.permissionBlocked =>
        _buildPermissionBlockedState(context, ui),
      RecordUiState.ready => _buildReadyState(context, ui),
      RecordUiState.recording => _buildRecordingState(context, ui),
      RecordUiState.processing => _buildProcessingState(context, ui),
      RecordUiState.done => _buildDoneState(context, ui),
      RecordUiState.error => _buildErrorState(context, ui),
    };
  }

  Widget _buildIdleState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildRequestingPermissionState(
    BuildContext context,
    RecordUiState ui,
  ) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildPermissionBlockedState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildReadyState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildRecordingState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildProcessingState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildDoneState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildErrorState(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBody(context, ui);

  Widget _buildRecordScreenBody(BuildContext context, RecordUiState ui) {
    final flags = _RecordUiFlags.from(ui);
`;

// Remove old header and listener block
src = src.replace(
  /^part of '\.\.\/\.\.\/screens\/record_screen\.dart';\s*\n\s*extension _RecordScreenStateBuild on _RecordScreenState \{\s*\n\s*Widget _buildRecordScreen\(BuildContext context\) \{\s*\n\s*ref\.listen\(recordingServiceProvider[\s\S]*?\}\);\s*\n\s*\n\s*var ui = _ui;/m,
  "",
);

if (!src.includes("_buildRecordScreenBody")) {
  src = dispatchHeader + src.replace(/^part of[\s\S]*?var ui = _ui;\s*\n/m, "");
}

// Remove audit override block for ui (moved to _resolveRecordBuildUi) but keep other audit overrides
src = src.replace(
  /var ui = _ui;\s*\n\s*var policyMic = _micPermission\.phase;/,
  "var policyMic = _micPermission.phase;",
);

src = src.replace(
  /if \(VisualAuditOverrides\.active\) \{\s*\n\s*final audit = VisualAuditOverrides\.peekRecordPresentation\(\);\s*\n\s*if \(audit != null\) \{\s*\n\s*ui = audit\.ui;\s*\n/m,
  "if (VisualAuditOverrides.active) {\n      final audit = VisualAuditOverrides.peekRecordPresentation();\n      if (audit != null) {\n",
);

// Close _buildRecordScreenBody at end
src = src.replace(/\n\}\n\}$/, "\n  }\n}\n");

fs.writeFileSync(buildPath, src);
console.log("Refactored", buildPath);
