#!/usr/bin/env node
/**
 * Generates RecordBuildContext + part files from extracted assembly block.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const assemblyBlock = fs.readFileSync("/tmp/recording_assembly.dart.txt", "utf8");
const listenerBlock = fs.readFileSync("/tmp/recording_listener.dart.txt", "utf8");

const decls = [];
const seen = new Set();
for (const line of assemblyBlock.split("\n")) {
  if (!/^    \S/.test(line)) continue;
  const m =
    line.match(
      /^    (?:(?:final|var)\s+)?(?:[\w<>,.?[\]\s]+\s+)?(\w+)\s*=/,
    ) ??
    line.match(
      /^    (?:(?:final|var)\s+)?(?:[\w<>,.?[\]\s]+\s+)?(\w+)\s*;/,
    );
  if (!m) continue;
  const name = m[1];
  if (seen.has(name)) continue;
  seen.add(name);
  decls.push({ name, type: "dynamic" });
}

const contextPath = path.join(root, "lib/features/recording/recording_build_context.dart");
const resolverPath = path.join(
  root,
  "lib/features/recording/recording_build_context_resolver.dart",
);
const adapterPath = path.join(
  root,
  "lib/features/recording/record_build_context_adapter.dart",
);
const listenerPath = path.join(root, "lib/features/recording/recording_audio_listener.dart");
const controllerPath = path.join(root, "lib/features/recording/recording_state_controller.dart");
const recordScreenPath = path.join(root, "lib/screens/record_screen.dart");

const contextClass = `part of '../../screens/record_screen.dart';

/// Immutable snapshot of gate/engine outputs for one record screen build.
class RecordBuildContext {
  const RecordBuildContext({
${decls.map((d) => `    required this.${d.name},`).join("\n")}
  });

${decls.map((d) => `  final ${d.type} ${d.name};`).join("\n")}
}
`;

const resolver = `part of '../../screens/record_screen.dart';

extension RecordingBuildContextResolver on _RecordScreenState {
  RecordBuildContext assembleRecordBuildContext(BuildContext context) {
${assemblyBlock}
    // NOTE: production path uses RecordSurfaceResolutionNotifier + adapter.
    throw UnimplementedError('Use resolver cutover path');
  }
}
`;

const listener = `part of '../../screens/record_screen.dart';

extension RecordingAudioListener on _RecordScreenState {
  void attachRecordingServiceListener(WidgetRef ref) {
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
  }
}
`;

let controller = fs.readFileSync(controllerPath, "utf8");

// Prefix assembly variable references in scaffold with ctx.
const names = decls.map((d) => d.name).sort((a, b) => b.length - a.length);
const scaffoldStart = controller.indexOf(
  "Widget _buildRecordScreenScaffold(BuildContext context, RecordBuildContext ctx) {",
);
const scaffoldEnd = controller.indexOf(
  "\n  Future<void> _dismissFirstSessionOnboarding()",
  scaffoldStart,
);
if (scaffoldStart < 0 || scaffoldEnd < 0) {
  throw new Error("scaffold bounds not found");
}
let scaffold = controller.slice(scaffoldStart, scaffoldEnd);

for (const name of names) {
  scaffold = scaffold.replace(
    new RegExp(`(?<![\\w.])${name}\\b(?!\\s*:)`, "g"),
    `ctx.${name}`,
  );
}
scaffold = scaffold.replace(/ctx\.context/g, "context");
scaffold = scaffold.replace(/ctx\.ctx\./g, "ctx.");

controller =
  controller.slice(0, scaffoldStart) + scaffold + controller.slice(scaffoldEnd);

fs.writeFileSync(contextPath, contextClass);
fs.writeFileSync(resolverPath, resolver);
fs.writeFileSync(adapterPath, "// regenerate adapter field map separately\n");
fs.writeFileSync(listenerPath, listener);
fs.writeFileSync(controllerPath, controller);

let recordScreen = fs.readFileSync(recordScreenPath, "utf8");
for (const p of [
  "part '../features/recording/recording_build_context.dart';",
  "part '../features/recording/recording_build_context_resolver.dart';",
  "part '../features/recording/record_build_context_adapter.dart';",
  "part '../features/recording/recording_audio_listener.dart';",
]) {
  if (!recordScreen.includes(p)) {
    recordScreen = recordScreen.replace(
      "part '../features/recording/recording_state_controller.dart';",
      `${p}\npart '../features/recording/recording_state_controller.dart';`,
    );
  }
}
fs.writeFileSync(recordScreenPath, recordScreen);

console.log("declarations:", decls.length);
console.log("context lines:", contextClass.split("\n").length);
console.log("assembler lines:", assembler.split("\n").length);
console.log("controller lines:", controller.split("\n").length);
