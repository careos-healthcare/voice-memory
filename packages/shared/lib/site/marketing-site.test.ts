import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  AUTH_EMAIL_FROM,
  CONTACT_EMAIL,
  LEGACY_MARKETING_DOMAIN,
  MARKETING_CONTACT_URL,
  MARKETING_DOMAIN,
  MARKETING_PRIVACY_URL,
  MARKETING_SITE_URL,
  isLegacyMarketingHost,
  resolveMarketingSiteUrl,
} from "./marketing-site";

describe("marketing-site", () => {
  it("uses archiveme.app as canonical marketing domain", () => {
    assert.equal(MARKETING_DOMAIN, "archiveme.app");
    assert.equal(MARKETING_SITE_URL, "https://archiveme.app");
    assert.equal(MARKETING_PRIVACY_URL, "https://archiveme.app/privacy");
    assert.equal(MARKETING_CONTACT_URL, "https://archiveme.app/contact");
  });

  it("publishes hello@archiveme.app as primary contact", () => {
    assert.equal(CONTACT_EMAIL, "hello@archiveme.app");
    assert.match(AUTH_EMAIL_FROM, /noreply@archiveme\.app/);
  });

  it("detects legacy voicememory.app host", () => {
    assert.equal(isLegacyMarketingHost(LEGACY_MARKETING_DOMAIN), true);
    assert.equal(isLegacyMarketingHost("www.voicememory.app"), true);
    assert.equal(isLegacyMarketingHost("archiveme.app"), false);
  });

  it("resolveMarketingSiteUrl prefers NEXT_PUBLIC_SITE_URL", () => {
    assert.equal(
      resolveMarketingSiteUrl({ NEXT_PUBLIC_SITE_URL: "https://staging.example" }),
      "https://staging.example",
    );
    assert.equal(resolveMarketingSiteUrl({}), MARKETING_SITE_URL);
  });
});
