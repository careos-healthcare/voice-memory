import assert from "node:assert/strict";
import { describe, it, beforeEach, afterEach } from "node:test";
import { validateProductionEnv } from "./production-env";
  const ENV_KEYS = [
    "DATABASE_URL",
    "AUTH_SECRET",
    "OPENAI_API_KEY",
    "NEXT_PUBLIC_APP_URL",
    "APP_URL",
    "STRIPE_SECRET_KEY",
    "STRIPE_WEBHOOK_SECRET",
    "STRIPE_PRO_PRICE_ID",
    "EMAIL_DISABLED",
  ] as const;
describe("validateProductionEnv", () => {
  const saved = new Map<string, string | undefined>();
  beforeEach(() => {
    for (const key of ENV_KEYS) {
      saved.set(key, process.env[key]);
    }
  });
  afterEach(() => {
    for (const key of ENV_KEYS) {
      const value = saved.get(key);
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  });
  it("does not fail strict validation when Stripe env is entirely absent", () => {
    process.env.DATABASE_URL = "postgres://localhost/test";
    process.env.AUTH_SECRET = "qk4mZ9vLpR2xNfWc7dJhTb1sYgE5uAoV";
    process.env.OPENAI_API_KEY = "sk-fixture-key";
    process.env.NEXT_PUBLIC_APP_URL = "https://example.com";
    process.env.EMAIL_DISABLED = "true";
    delete process.env.STRIPE_SECRET_KEY;
    delete process.env.STRIPE_WEBHOOK_SECRET;
    delete process.env.STRIPE_PRO_PRICE_ID;
    const result = validateProductionEnv({ strict: true });
    assert.equal(
      result.issues.some((issue) => issue.code === "STRIPE"),
      false,
    );
    assert.equal(result.ok, true, JSON.stringify(result.issues));
  });
});
