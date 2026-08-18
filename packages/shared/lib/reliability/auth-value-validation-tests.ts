import assert from "node:assert/strict";

import {
  shouldPromptForAuthTrigger,
} from "@/lib/auth/auth-trigger-rules";
import {
  buildAuthValueValidationReport,
  clearAuthValueValidationEventsForEval,
} from "@/lib/auth/auth-value-validation";
import {
  GUEST_FIRST_AUTH_EVENTS,
  trackAuthPromptShown,
  trackAuthVerified,
  trackProtectArchiveClicked,
} from "@/lib/auth/guest-first-auth";
import { trackLocalEvent } from "@/lib/local-analytics";

export async function runAuthValueValidationTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("no auth prompt before first reflection", () => {
    assert.equal(
      shouldPromptForAuthTrigger("export", { isSignedIn: false, reflectionCount: 0 }),
      false,
    );
    assert.equal(
      shouldPromptForAuthTrigger("protect_archive", { isSignedIn: false, reflectionCount: 0 }),
      false,
    );
  });

  await check("protect archive allowed after reflection 1", () => {
    assert.equal(
      shouldPromptForAuthTrigger("protect_archive", { isSignedIn: false, reflectionCount: 2 }),
      true,
    );
  });

  const storage = new Map<string, string>();
  const localStorage = {
    getItem: (k: string) => storage.get(String(k)) ?? null,
    setItem: (k: string, v: string) => storage.set(String(k), String(v)),
    removeItem: (k: string) => storage.delete(String(k)),
    clear: () => storage.clear(),
    get length() {
      return storage.size;
    },
    key: (i: number) => [...storage.keys()][i] ?? null,
  };
  (globalThis as { window: Window }).window = { localStorage } as unknown as Window;
  (globalThis as { localStorage: Storage }).localStorage = localStorage as unknown as Storage;

  clearAuthValueValidationEventsForEval();

  await check("protect archive conversion rate computes", () => {
    trackProtectArchiveClicked();
    trackAuthPromptShown("protect_archive");
    trackAuthVerified("protect_archive");
    const report = buildAuthValueValidationReport();
    assert.equal(report.protectArchiveClicked, 1);
    assert.equal(report.protectArchiveConversionRate, 100);
    assert.ok(report.authPromptsShown >= 1);
    assert.ok(report.authVerified >= 1);
  });

  await check("report includes funnel rows", () => {
    const report = buildAuthValueValidationReport();
    assert.ok(report.funnelByReason.some((r) => r.reason === "protect_archive"));
  });

  return { failures };
}
