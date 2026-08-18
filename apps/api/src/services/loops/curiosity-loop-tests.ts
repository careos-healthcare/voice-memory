import assert from "node:assert/strict";

import { buildCuriosityHook } from "@/src/services/loops/curiosity_hook_engine";
import { curiosityAdaptiveTimingEngine } from "@/src/services/loops/curiosity_adaptive_timing_engine";
import {
  buildCuriosityNotificationMessage,
  isGenericCuriosityPrompt,
} from "@/src/services/loops/curiosity_notification_message_builder";

export async function runCuriosityLoopTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  try {
    const hook = buildCuriosityHook({
      metadata: {
        entryId: "entry-1",
        createdAt: "2026-06-12T12:00:00.000Z",
        extractedAnchors: ["said yes again"],
        entryCount: 2,
      },
    });
    assert.ok(hook);
    assert.equal(hook.hookType, "anchorFollowUp");
    assert.equal(hook.primaryAnchor, "said yes again");
  } catch (error) {
    failures.push(`buildCuriosityHook failed: ${error}`);
  }

  try {
    const delay = curiosityAdaptiveTimingEngine.calculateOptimalDelayMs({
      history: [
        { createdAt: "2026-06-10T09:00:00.000Z" },
        { createdAt: "2026-06-11T09:30:00.000Z" },
        { createdAt: "2026-06-12T10:00:00.000Z" },
      ],
      currentEntryTime: new Date("2026-06-12T15:00:00.000Z"),
    });
    assert.ok(delay > 0);
  } catch (error) {
    failures.push(`calculateOptimalDelayMs failed: ${error}`);
  }

  try {
    assert.equal(isGenericCuriosityPrompt("What's on your mind today?"), true);
    assert.equal(
      isGenericCuriosityPrompt(
        'This line keeps showing up in your archive: "I keep postponing the mortgage talk". What do you notice about it today?',
      ),
      false,
    );

    const message = buildCuriosityNotificationMessage({
      hook: {
        id: "curiosity_entry-1_1",
        entryId: "entry-1",
        createdAt: "2026-06-12T12:00:00.000Z",
        primaryAnchor: "mortgage talk",
        hookType: "anchorFollowUp",
      },
      evidence: {
        eligible: true,
        reason: "solid_pattern",
        confidenceBand: "solid",
        citedEntryIds: ["entry-1", "entry-2"],
        themeLabel: "mortgage",
        excerpt: "I keep postponing the mortgage talk with my partner",
        contradictionEntryIds: null,
        surfaceKey: "pattern:entry-1|entry-2",
      },
    });
    assert.ok(message);
    assert.match(message.body, /mortgage talk/i);
    assert.doesNotMatch(message.body, /what's on your mind/i);
  } catch (error) {
    failures.push(`notification message builder failed: ${error}`);
  }

  return { failures };
}
