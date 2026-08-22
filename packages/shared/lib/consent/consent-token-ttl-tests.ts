import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

import {
  CAREGIVER_CONSENT_DEFAULT_TTL_MS,
  COACH_CONSENT_DEFAULT_TTL_MS,
} from "@/lib/consent/consent-token-ttl";
import { issueMonitoringConsentToken } from "@/lib/caregiver/consent-verification";
import { issueCoachConsentToken } from "@/lib/coach/client-consent-verification";

const DAY_MS = 1000 * 60 * 60 * 24;

export async function runConsentTokenTtlTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(
        `${name}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  await check("caregiver consent defaults to 7 days", () => {
    assert.equal(CAREGIVER_CONSENT_DEFAULT_TTL_MS, 7 * DAY_MS);
  });

  await check("coach consent defaults to 30 days", () => {
    assert.equal(COACH_CONSENT_DEFAULT_TTL_MS, 30 * DAY_MS);
  });

  await check("both defaults are shorter than the pre-revocation ones", () => {
    assert.ok(CAREGIVER_CONSENT_DEFAULT_TTL_MS < 30 * DAY_MS);
    assert.ok(COACH_CONSENT_DEFAULT_TTL_MS < 90 * DAY_MS);
  });

  await check("an issued caregiver token expires on the single default", async () => {
    const now = new Date("2026-01-01T00:00:00.000Z");
    const token = await issueMonitoringConsentToken({
      tokenId: randomUUID(),
      subjectAccountId: "owner",
      caregiverId: "caregiver",
      permissions: {
        evidenceStreamIds: [],
        reviewSummaries: true,
        thresholdAlerts: false,
      },
      signingSecret: "test-secret",
      now,
    });
    assert.equal(
      new Date(token.expiresAt).getTime() - now.getTime(),
      CAREGIVER_CONSENT_DEFAULT_TTL_MS,
    );
  });

  await check("an issued coach token expires on the single default", async () => {
    const now = new Date("2026-01-01T00:00:00.000Z");
    const token = await issueCoachConsentToken({
      tokenId: randomUUID(),
      relationshipId: randomUUID(),
      clientAccountId: "owner",
      coachId: "coach",
      permissions: {
        factLedger: false,
        confidenceBandedInsights: true,
        insightKinds: ["belief"],
      },
      clientAffirmationHash: "hash",
      signingSecret: "test-secret",
      now,
    });
    assert.equal(
      new Date(token.expiresAt).getTime() - now.getTime(),
      COACH_CONSENT_DEFAULT_TTL_MS,
    );
  });

  await check("an explicit ttlMs still overrides the default", async () => {
    const now = new Date("2026-01-01T00:00:00.000Z");
    const token = await issueMonitoringConsentToken({
      tokenId: randomUUID(),
      subjectAccountId: "owner",
      caregiverId: "caregiver",
      permissions: {
        evidenceStreamIds: [],
        reviewSummaries: true,
        thresholdAlerts: false,
      },
      signingSecret: "test-secret",
      ttlMs: 60_000,
      now,
    });
    assert.equal(new Date(token.expiresAt).getTime() - now.getTime(), 60_000);
  });

  return { failures };
}
