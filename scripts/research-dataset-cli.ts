#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import type { CompletedEvaluationRecord } from "../packages/shared/lib/research/blind-review";
import {
  type HumanCaseInput,
  type SyntheticCaseInput,
} from "../packages/shared/lib/research/research-domain";
import {
  buildResearchExportBundle,
  serializeResearchExport,
} from "../packages/shared/lib/research/research-export";
import { JsonResearchRepository } from "../packages/shared/lib/research/research-repository";

async function readJson<T>(filePath: string): Promise<T> {
  return JSON.parse(await readFile(filePath, "utf8")) as T;
}

export async function runResearchDatasetCli(args: readonly string[]): Promise<void> {
  const [command, localRoot, firstPath, secondPath] = args;
  if (!command || !localRoot || !firstPath) {
    throw new Error(
      "Usage: research-dataset-cli <add-synthetic|add-human|export> <local-root> <input-or-output.json> [evaluations.json]",
    );
  }
  const repository = new JsonResearchRepository(localRoot);
  if (command === "add-synthetic") {
    await repository.addSynthetic(
      await readJson<SyntheticCaseInput>(firstPath),
    );
    return;
  }
  if (command === "add-human") {
    await repository.addHuman(await readJson<HumanCaseInput>(firstPath));
    return;
  }
  if (command === "export") {
    const evaluations = secondPath
      ? await readJson<CompletedEvaluationRecord[]>(secondPath)
      : [];
    const bundle = buildResearchExportBundle({
      syntheticCases: await repository.listSynthetic(),
      humanCases: await repository.listHuman(),
      evaluations,
      exportedAt: new Date().toISOString(),
    });
    await writeFile(firstPath, serializeResearchExport(bundle), {
      encoding: "utf8",
      mode: 0o600,
    });
    return;
  }
  throw new Error(`Unknown research dataset command: ${command}`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  runResearchDatasetCli(process.argv.slice(2)).catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : "Research CLI failed");
    process.exitCode = 1;
  });
}
