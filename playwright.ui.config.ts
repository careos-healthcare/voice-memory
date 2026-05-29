import { defineConfig } from "@playwright/test";

const port = Number(process.env.PLAYWRIGHT_PORT ?? "3113");
const baseURL = `http://127.0.0.1:${port}`;

const webServerEnv = {
  ...process.env,
  NODE_ENV: "production",
  VOICEMEMORY_UI_E2E: "1",
  EMAIL_DISABLED: "true",
  AUTH_SECRET: process.env.AUTH_SECRET ?? "e2e-test-auth-secret-min-32-chars-long",
};

export default defineConfig({
  testDir: "e2e",
  testMatch: ["**/ui-*.spec.ts"],
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL,
    trace: "off",
  },
  webServer: {
    command: `npm run start -- -p ${port}`,
    url: baseURL,
    reuseExistingServer: false,
    timeout: 120_000,
    env: webServerEnv,
  },
  projects: [
    {
      name: "smoke",
      testMatch: "**/ui-smoke.spec.ts",
    },
    {
      name: "mobile",
      testMatch: "**/ui-mobile-375.spec.ts",
      use: {
        viewport: { width: 375, height: 667 },
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: "a11y",
      testMatch: "**/ui-a11y.spec.ts",
      timeout: 90_000,
    },
    {
      name: "a11y-full",
      testMatch: "**/ui-a11y-full.spec.ts",
      timeout: 120_000,
      use: {
        viewport: { width: 375, height: 667 },
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: "a11y-dynamic",
      testMatch: "**/ui-a11y-dynamic.spec.ts",
      timeout: 120_000,
      use: {
        viewport: { width: 375, height: 667 },
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: "a11y-dynamic-permutations",
      testMatch: "**/ui-a11y-dynamic-permutations.spec.ts",
      timeout: 180_000,
      use: {
        viewport: { width: 375, height: 667 },
        isMobile: true,
        hasTouch: true,
      },
    },
    {
      name: "sr-structure",
      testMatch: "**/ui-screen-reader-structure.spec.ts",
      timeout: 90_000,
    },
    {
      name: "runtime-proof",
      testMatch: "**/runtime-proof.spec.ts",
      timeout: 60_000,
    },
    {
      name: "hostile-proof",
      testMatch: "**/hostile-proof.spec.ts",
      timeout: 60_000,
    },
    {
      name: "debug",
      testMatch: "**/ui-debug-regression.spec.ts",
    },
  ],
});
