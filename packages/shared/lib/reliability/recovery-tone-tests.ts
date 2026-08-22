import assert from "node:assert/strict";

import { buildLifeStageLensSystemBlock } from "@/lib/archive-synthesis/prompt-context-contract";
import {
  RECOVERY_ACCEPTABLE_MIRROR_EXAMPLES,
  RECOVERY_FORBIDDEN_MOCK_OUTPUTS,
  RECOVERY_SYSTEM_PROMPT_INJECTION,
  validateRecoveryTone,
} from "@/lib/lenses/recovery-lens";

export async function runRecoveryToneTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(
        `${name}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  check("recovery lens block uses strict neutral-mirror injection", () => {
    const block = buildLifeStageLensSystemBlock("recovery");
    assert.ok(block.includes("RECOVERY / SOBRIETY LENS"));
    assert.ok(block.includes("STRICT PROHIBITIONS"));
    assert.ok(block.includes(RECOVERY_SYSTEM_PROMPT_INJECTION.split("\n")[1]!));
  });

  check("acceptable mirror examples pass tone validation", () => {
    for (const example of RECOVERY_ACCEPTABLE_MIRROR_EXAMPLES) {
      const result = validateRecoveryTone({ insightText: example });
      assert.deepEqual(result, [], example);
    }
  });

  check("forbidden mock outputs fail tone validation", () => {
    for (const mock of RECOVERY_FORBIDDEN_MOCK_OUTPUTS) {
      const result = validateRecoveryTone({ insightText: mock });
      assert.ok(result.length > 0, `expected failure for: ${mock}`);
    }
  });

  check("clinical guidance patterns are rejected", () => {
    const samples = [
      "You should consider seeking therapy for these triggers.",
      "It sounds like you may be experiencing relapse warning signs.",
      "Try a coping strategy when cravings hit.",
    ];
    for (const sample of samples) {
      assert.ok(
        validateRecoveryTone({ insightText: sample }).length > 0,
        sample,
      );
    }
  });

  return { failures };
}
