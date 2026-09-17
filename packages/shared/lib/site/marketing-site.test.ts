import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  AUTH_EMAIL_FROM,
  CONTACT_EMAIL,
  LEGACY_MARKETING_DOMAINS,
  MARKETING_CONTACT_URL,
  MARKETING_DOMAIN,
  MARKETING_PRIVACY_URL,
  MARKETING_SITE_URL,
  isLegacyMarketingHost,
  resolveMarketingSiteUrl,
} from "./marketing-site";

describe("marketing-site", () => {
  it("uses thoughtprint.xyz as canonical marketing domain", () => {
    assert.equal(MARKETING_DOMAIN, "thoughtprint.xyz");
    assert.equal(MARKETING_SITE_URL, "https://thoughtprint.xyz");
    assert.equal(MARKETING_PRIVACY_URL, "https://thoughtprint.xyz/privacy");
    assert.equal(MARKETING_CONTACT_URL, "https://thoughtprint.xyz/contact");
  });

  it("publishes hello@thoughtprint.xyz as primary contact", () => {
    assert.equal(CONTACT_EMAIL, "hello@thoughtprint.xyz");
    assert.match(AUTH_EMAIL_FROM, /noreply@thoughtprint\.xyz/);
  });

  it("detects legacy archiveme.app and voicememory.app hosts", () => {
    for (const domain of LEGACY_MARKETING_DOMAINS) {
      assert.equal(isLegacyMarketingHost(domain), true);
      assert.equal(isLegacyMarketingHost(`www\.${domain}`), true);
    }
    assert.equal(isLegacyMarketingHost("thoughtprint.xyz"), false);
  });

  it("resolveMarketingSiteUrl prefers NEXT_PUBLIC_SITE_URL", () => {
    assert.equal(
      resolveMarketingSiteUrl({ NEXT_PUBLIC_SITE_URL: "https://staging.example" }),
      "https://staging.example",
    );
    assert.equal(resolveMarketingSiteUrl({}), MARKETING_SITE_URL);
  });
});
