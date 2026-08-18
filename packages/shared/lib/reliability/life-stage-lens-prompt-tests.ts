import assert from "node:assert/strict";

import {
  buildLifeStageLensSystemBlock,
  composeFactLedgerSystemPrompt,
  LIFE_STAGE_LENS_HEADER,
} from "@/lib/archive-synthesis/prompt-context-contract";

const BASE = "BASE PROMPT";

export async function runLifeStageLensPromptTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  check("default lens leaves base prompt unchanged", () => {
    const result = composeFactLedgerSystemPrompt({
      baseSystemPrompt: BASE,
      activeLens: "default",
    });
    assert.equal(result, BASE);
  });

  check("thematic lens appends header without replacing base", () => {
    const result = composeFactLedgerSystemPrompt({
      baseSystemPrompt: BASE,
      activeLens: "newParent",
    });
    assert.ok(result.startsWith(BASE));
    assert.ok(result.includes(LIFE_STAGE_LENS_HEADER));
    assert.ok(result.includes("ArchiveInsightKind taxonomy is unchanged"));
  });

  check("buildLifeStageLensSystemBlock is empty for default", () => {
    assert.equal(buildLifeStageLensSystemBlock("default"), "");
  });

  check("career transition lens block includes listen targets", () => {
    const block = buildLifeStageLensSystemBlock("careerTransition");
    assert.ok(block.includes("professional identity shifts"));
    assert.ok(block.includes("skill-transfer beliefs"));
    assert.ok(block.includes("risk-tolerance contradictions"));
    assert.ok(block.includes("definitions of success"));
  });

  check("recovery lens block includes strict neutral-mirror guardrails", () => {
    const block = buildLifeStageLensSystemBlock("recovery");
    assert.ok(block.includes("RECOVERY / SOBRIETY LENS"));
    assert.ok(block.includes("STRICT PROHIBITIONS"));
    assert.ok(block.includes("rationalizations"));
    assert.ok(!block.includes("Never diagnose or prescribe"));
    assert.ok(block.includes("clinical advice"));
  });

  check("new parent lens block includes capacity and identity shifts", () => {
    const block = buildLifeStageLensSystemBlock("newParent");
    assert.ok(block.includes("NEW PARENT LENS"));
    assert.ok(block.includes("patience"));
    assert.ok(block.includes("pre-transition vs post-transition"));
  });

  check("grief loss lens block forbids progress framing", () => {
    const block = buildLifeStageLensSystemBlock("griefLoss");
    assert.ok(block.includes("GRIEF / LOSS LENS"));
    assert.ok(block.includes("cyclical patterns"));
    assert.ok(block.includes("progress, healing, closure"));
  });

  check("each thematic lens has instruction text", () => {
    for (const lens of [
      "newParent",
      "careerTransition",
      "recovery",
      "griefLoss",
    ] as const) {
      const block = buildLifeStageLensSystemBlock(lens);
      assert.ok(block.length > 40, `${lens} block too short`);
    }
  });

  return { failures };
}
