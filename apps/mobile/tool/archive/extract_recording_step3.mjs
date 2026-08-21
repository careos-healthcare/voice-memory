#!/usr/bin/env node
/**
 * Step 3: extract UI dispatch + handlers from recording_state_controller.dart.
 * Pure structural move — no behavior changes.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const recordingDir = path.join(root, "lib/features/recording");
const viewsDir = path.join(recordingDir, "views");
const widgetsDir = path.join(recordingDir, "widgets");
const controllerPath = path.join(recordingDir, "recording_state_controller.dart");
const recordScreenPath = path.join(root, "lib/screens/record_screen.dart");
const planPath = path.join(recordingDir, "REFACTORING_PLAN.md");

for (const dir of [viewsDir, widgetsDir]) {
  fs.mkdirSync(dir, { recursive: true });
}

const lines = fs.readFileSync(controllerPath, "utf8").split("\n");

function slice(start, end) {
  return lines.slice(start - 1, end).join("\n");
}

function dedentBlock(block, fromSpaces, toSpaces = 6) {
  const prefix = " ".repeat(fromSpaces);
  return block
    .split("\n")
    .map((line) => {
      if (line.length === 0) return line;
      if (line.startsWith(prefix)) {
        return " ".repeat(toSpaces) + line.slice(fromSpaces);
      }
      return line;
    })
    .join("\n");
}

function partHeader() {
  return "part of '../../screens/record_screen.dart';\n";
}

// Lifecycle ends after _loadDefaultBoundaryPause (line 1911).
const lifecycleBlock = slice(1, 1911);

// Handler block: policy helpers through _compactLayout, excluding widget builders.
const handlersBlock = [
  slice(1913, 2174),
  slice(2201, 2567),
  slice(2568, 3009),
  slice(6716, 6734),
].join("\n");

const captureActionsBlock = slice(2175, 2200);
const policyButtonsBlock = slice(6736, 6782);
const bottomActionsBlock = slice(6784, 7280);

// Column children inside scaffold (lines 3047-6679).
const columnChildrenBlock = slice(3047, 6679);
const columnLines = columnChildrenBlock.split("\n");

const preCaptureEnd = 4765 - 3047 + 1;
const permissionEnd = 4804 - 3047 + 1;
const captureStateEnd = 5120 - 3047 + 1;

const preCaptureBlock = dedentBlock(columnLines.slice(0, preCaptureEnd).join("\n"), 24);
const permissionBlock = dedentBlock(columnLines.slice(preCaptureEnd, permissionEnd).join("\n"), 24);
const captureStateBlock = dedentBlock(
  columnLines.slice(permissionEnd, captureStateEnd).join("\n"),
  24,
);
const postSaveBlock = dedentBlock(columnLines.slice(captureStateEnd).join("\n"), 24);

const dispatchFile = `${partHeader()}
extension RecordScreenBuildDispatch on _RecordScreenState {
  List<Widget> _buildRecordScreenBodyChildren(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
      ..._buildRecordPreCaptureCards(context, ctx),
      _buildRecordingPermissionPanel(context, ctx),
      ..._buildRecordCaptureStateSection(context, ctx),
      ..._buildRecordPostSaveCards(context, ctx),
    ];
  }
}
`;

const preCaptureFile = `${partHeader()}
extension RecordPreCaptureCards on _RecordScreenState {
  List<Widget> _buildRecordPreCaptureCards(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
${preCaptureBlock}
    ];
  }
}
`;

const permissionFile = `${partHeader()}
extension RecordingPermissionPanel on _RecordScreenState {
  Widget _buildRecordingPermissionPanel(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return ${permissionBlock.trimStart()};
  }
}
`;

const captureStateFile = `${partHeader()}
extension RecordCaptureStateSection on _RecordScreenState {
  List<Widget> _buildRecordCaptureStateSection(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
${captureStateBlock}
    ];
  }
}
`;

const postSaveFile = `${partHeader()}
extension RecordPostSaveCards on _RecordScreenState {
  List<Widget> _buildRecordPostSaveCards(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return [
${postSaveBlock}
    ];
  }
}
`;

const bodyFile = `${partHeader()}
extension RecordScreenBody on _RecordScreenState {
  Widget _buildRecordScreenBody(BuildContext context, RecordBuildContext ctx) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const Key('record_screen_scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            ctx.firstUseSimplifiedRecord ? 0 : 8,
            24,
            (ctx.compact ? 12.0 : 16.0) + ctx.bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: ctx.firstUseSimplifiedRecord
                  ? 0
                  : constraints.maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildRecordScreenBodyChildren(context, ctx),
                ..._buildBottomActions(
                  context,
                  ui: ctx.ui,
                  canRecord: ctx.canRecord,
                  localSaveTitle: ctx.localSaveTitle,
                  selectedPrompt: _selectedPromptLine,
                  suppressDuplicateRecordCtas:
                      ctx.stack.suppressDuplicateRecordCtas ||
                      ctx.suppressNoisyFirstSaveCards ||
                      (ctx.suppressNoisyRepeatPostSaveCards &&
                          !ctx.showWhatChangedV2 &&
                          !ctx.showWhatChangedV2Display) ||
                      ctx.showDegradedTranscriptFocusedPostSave,
                  showReturningWatchTargetFocusedUi:
                      ctx.showReturningWatchTargetFocusedUi,
                  policyMicPhase: ctx.policyMic,
                  policyUserDenied: ctx.policyUserDenied,
                  recordHomeSurface: ctx.recordHomeSurface,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
`;

const scaffoldFile = `${partHeader()}
extension RecordScreenScaffold on _RecordScreenState {
  Widget _buildRecordScreenScaffold(BuildContext context, RecordBuildContext ctx) {
    return ColoredBox(
      color: recordScreenBackground,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            _buildRecordScreenBody(context, ctx),
            if (ctx.showCloseButton)
              const Align(
                alignment: Alignment.topRight,
                child: RecordScreenCloseButton(),
              ),
          ],
        ),
      ),
    );
  }
}
`;

const captureActionsFile = `${partHeader()}
extension RecordingCaptureActionsWidget on _RecordScreenState {
${captureActionsBlock}
}
`;

const controlsFile = `${partHeader()}
extension RecordingControlsWidget on _RecordScreenState {
${policyButtonsBlock}

${bottomActionsBlock}
}
`;

const handlersFile = `${partHeader()}
extension RecordingStateHandlers on _RecordScreenState {
${handlersBlock}
}
`;

const newController = `${lifecycleBlock}

  @override
  Widget build(BuildContext context) {
    attachRecordingServiceListener(ref);
    final ctx = assembleRecordBuildContext(context);
    return _buildRecordScreenScaffold(context, ctx);
  }
}
`;

const partFiles = [
  ["recording_state_handlers.dart", handlersFile],
  ["recording_state_build_dispatch.dart", dispatchFile],
  ["views/record_pre_capture_cards.dart", preCaptureFile],
  ["widgets/recording_permission_panel.dart", permissionFile],
  ["views/record_capture_state_section.dart", captureStateFile],
  ["views/record_post_save_cards.dart", postSaveFile],
  ["views/record_screen_body.dart", bodyFile],
  ["views/record_screen_scaffold.dart", scaffoldFile],
  ["widgets/recording_capture_actions_widget.dart", captureActionsFile],
  ["widgets/recording_controls_widget.dart", controlsFile],
];

for (const [rel, content] of partFiles) {
  const out = path.join(recordingDir, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, content.replace(/\n{3,}/g, "\n\n") + "\n");
}

fs.writeFileSync(controllerPath, newController);

// Replace private nudge widget with shared widget.
const scaffoldPath = path.join(recordingDir, "views/record_post_save_cards.dart");
let postSaveContent = fs.readFileSync(scaffoldPath, "utf8");
postSaveContent = postSaveContent.replaceAll(
  "_SuggestionProNudgeCard(",
  "SuggestionProNudgeCard(",
);
fs.writeFileSync(scaffoldPath, postSaveContent);

for (const rel of [
  "widgets/recording_controls_widget.dart",
  "views/record_pre_capture_cards.dart",
  "views/record_capture_state_section.dart",
]) {
  const p = path.join(recordingDir, rel);
  let c = fs.readFileSync(p, "utf8");
  c = c.replaceAll("_SuggestionProNudgeCard(", "SuggestionProNudgeCard(");
  fs.writeFileSync(p, c);
}

const newParts = partFiles.map(([rel]) => {
  const normalized = rel.startsWith("views/") || rel.startsWith("widgets/")
    ? `../features/recording/${rel}`
    : `../features/recording/${rel}`;
  return `part '${normalized}';`;
});

let recordScreen = fs.readFileSync(recordScreenPath, "utf8");
const insertAfter =
  "part '../features/recording/recording_audio_listener.dart';";
if (!recordScreen.includes("recording_state_handlers.dart")) {
  recordScreen = recordScreen.replace(
    insertAfter,
    `${insertAfter}\n${newParts.join("\n")}`,
  );
}

if (!recordScreen.includes("suggestion_pro_nudge_card.dart")) {
  recordScreen = recordScreen.replace(
    "import 'package:flutter_riverpod/flutter_riverpod.dart';",
    "import 'package:archiveme_mobile/features/recording/widgets/suggestion_pro_nudge_card.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';",
  );
}

fs.writeFileSync(recordScreenPath, recordScreen);

let plan = fs.readFileSync(planPath, "utf8");
plan = plan.replace(
  "- [ ] `recording_state_build_dispatch.dart`",
  "- [x] `recording_state_build_dispatch.dart`",
);
for (const item of [
  "views/record_screen_scaffold.dart",
  "views/record_pre_capture_cards.dart",
  "views/record_post_save_cards.dart",
  "views/record_screen_body.dart",
  "widgets/recording_controls_widget.dart",
  "widgets/recording_capture_actions_widget.dart",
  "widgets/recording_permission_panel.dart",
]) {
  plan = plan.replace(`- [ ] \`${item}\``, `- [x] \`${item}\``);
}
fs.writeFileSync(planPath, plan);

console.log("Step 3 extraction complete.");
console.log(`controller lines: ${newController.split("\n").length}`);
