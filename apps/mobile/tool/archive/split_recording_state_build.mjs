#!/usr/bin/env node
/**
 * Splits recording_state_build.dart into dispatch + body part files.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const buildPath = path.join(root, "lib/features/recording/recording_state_build.dart");
const src = fs.readFileSync(buildPath, "utf8");

const extensionStart = src.indexOf("extension _RecordScreenStateBuild");
const bodyMethodStart = src.indexOf("  Widget _buildRecordScreenBody(");
if (extensionStart < 0 || bodyMethodStart < 0) {
  throw new Error("Could not locate extension or body method");
}

const header = src.slice(0, bodyMethodStart);
const bodyMethod = src.slice(bodyMethodStart);

const dispatchPath = path.join(root, "lib/features/recording/recording_state_build_dispatch.dart");
const bodyPath = path.join(root, "lib/features/recording/recording_state_build_body.dart");

const dispatchContent = `${header}  Widget _buildRecordScreenBody(BuildContext context, RecordUiState ui) =>
      _buildRecordScreenBodyContent(context, ui);
}
`;

const bodyContent = `part of '../../screens/record_screen.dart';

extension _RecordScreenStateBuildBody on _RecordScreenState {
${bodyMethod}}
`;

fs.writeFileSync(dispatchPath, dispatchContent);
fs.writeFileSync(bodyPath, bodyContent.replace("Widget _buildRecordScreenBody", "Widget _buildRecordScreenBodyContent"));

console.log("Dispatch lines:", dispatchContent.split("\n").length);
console.log("Body lines:", bodyContent.split("\n").length);
