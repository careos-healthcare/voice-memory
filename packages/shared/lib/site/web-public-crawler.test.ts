import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";

import {
  RETIRED_CONSUMER_ROUTE_PREFIXES,
  isWebMarketingNavHref,
} from "./web-public-production-routes";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../..");
const WEB = path.join(ROOT, "apps/web");

const CRAWL_FILES = [
  "app/page.tsx",
  "app/beta/page.tsx",
  "app/welcome/page.tsx",
  "components/SiteHeader.tsx",
  "components/SiteFooter.tsx",
  "app/contact/page.tsx",
  "app/privacy/page.tsx",
  "app/terms/page.tsx",
  "app/safety/page.tsx",
];

const HREF_PATTERN = /href=["'{]([^"'{}]+)["'}]/g;

function collectHrefs(filePath: string): string[] {
  const text = fs.readFileSync(filePath, "utf8");
  const hrefs: string[] = [];
  for (const match of text.matchAll(HREF_PATTERN)) {
    const href = match[1]?.trim();
    if (href && href.startsWith("/")) hrefs.push(href);
  }
  return hrefs;
}

describe("web marketing crawler", () => {
  it("public marketing files link only to allowed routes", () => {
    const violations: string[] = [];

    for (const rel of CRAWL_FILES) {
      const abs = path.join(WEB, rel);
      assert.ok(fs.existsSync(abs), `missing ${rel}`);
      for (const href of collectHrefs(abs)) {
        if (!isWebMarketingNavHref(href) && !href.startsWith("#")) {
          violations.push(`${rel}: ${href}`);
        }
      }
    }

    assert.equal(violations.length, 0, violations.join("\n"));
  });

  it("does not link to known retired consumer prefixes from homepage", () => {
    const home = fs.readFileSync(path.join(WEB, "app/page.tsx"), "utf8");
    for (const prefix of RETIRED_CONSUMER_ROUTE_PREFIXES) {
      assert.ok(
        !home.includes(`href="${prefix}"`) && !home.includes(`href='${prefix}'`),
        `homepage links to retired route ${prefix}`,
      );
    }
  });
});
