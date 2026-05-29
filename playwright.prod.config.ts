import { defineConfig } from "@playwright/test";

const port = Number(process.env.PLAYWRIGHT_PORT ?? "3112");
const baseURL = `http://127.0.0.1:${port}`;

/** Production-like E2E — `next start` + NODE_ENV=production for internal/demo gates. */
export default defineConfig({
  testDir: "e2e",
  testMatch: [
    "**/api-security.spec.ts",
    "**/prod-hardening.spec.ts",
    "**/ui-internal-prod.spec.ts",
  ],
  timeout: 45_000,
  retries: process.env.CI ? 1 : 0,
  use: { baseURL, trace: "off" },
  webServer: {
    command: `npm run start -- -p ${port}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
    env: {
      ...process.env,
      NODE_ENV: "production",
      VOICEMEMORY_UI_E2E: "1",
      EMAIL_DISABLED: "true",
      AUTH_SECRET: process.env.AUTH_SECRET ?? "e2e-test-auth-secret-min-32-chars-long",
    },
  },
});
