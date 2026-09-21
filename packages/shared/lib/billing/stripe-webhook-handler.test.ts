import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { userIdFromStripeMetadata } from "./stripe-webhook-handler";

describe("userIdFromStripeMetadata", () => {
  it("returns the userId when present as a non-empty string", () => {
    assert.equal(userIdFromStripeMetadata({ userId: "user_123" }), "user_123");
  });

  it("returns null when metadata is null or undefined", () => {
    assert.equal(userIdFromStripeMetadata(null), null);
    assert.equal(userIdFromStripeMetadata(undefined), null);
  });

  it("returns null when userId is missing or empty", () => {
    assert.equal(userIdFromStripeMetadata({}), null);
    assert.equal(userIdFromStripeMetadata({ userId: "" }), null);
  });
});
