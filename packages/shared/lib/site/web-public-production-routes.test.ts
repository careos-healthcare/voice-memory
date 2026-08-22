import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  RETIRED_CONSUMER_ROUTE_PREFIXES,
  WEB_PUBLIC_PRODUCTION_ROUTES,
  WEB_PUBLIC_REDIRECTS,
  isPublicProductionPath,
  isRetiredConsumerPath,
  resolvePublicRedirect,
} from "./web-public-production-routes";

describe("web public production routes", () => {
  it("allowlists only marketing, legal, support, and beta paths", () => {
    assert.deepEqual(WEB_PUBLIC_PRODUCTION_ROUTES, [
      "/",
      "/welcome",
      "/beta",
      "/privacy",
      "/terms",
      "/contact",
      "/safety",
    ]);
  });

  it("classifies retired consumer prefixes", () => {
    for (const path of ["/journal", "/weekly", "/archive-belief", "/record", "/theories"]) {
      assert.equal(isRetiredConsumerPath(path), true, path);
    }
    assert.equal(isRetiredConsumerPath("/privacy"), false);
    assert.equal(isRetiredConsumerPath("/beta"), false);
  });

  it("redirects privacy-simple and support to canonical pages", () => {
    assert.equal(resolvePublicRedirect("/privacy-simple"), "/privacy");
    assert.equal(resolvePublicRedirect("/support"), "/contact");
  });

  it("does not redirect retired routes into loops", () => {
    for (const prefix of RETIRED_CONSUMER_ROUTE_PREFIXES) {
      const target = resolvePublicRedirect(prefix);
      if (target) {
        assert.notEqual(target, prefix);
      }
    }
  });

  it("keeps public paths off retired list", () => {
    for (const route of WEB_PUBLIC_PRODUCTION_ROUTES) {
      assert.equal(isPublicProductionPath(route), true);
      assert.equal(isRetiredConsumerPath(route), false);
    }
  });

  it("redirect targets are public production paths", () => {
    for (const target of Object.values(WEB_PUBLIC_REDIRECTS)) {
      assert.equal(isPublicProductionPath(target), true);
    }
  });
});
