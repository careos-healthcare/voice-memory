import assert from "node:assert/strict";
import { describe, it, beforeEach } from "node:test";

import {
  setRedemptionCodeBackendForTest,
  issueRedemptionCode,
  redeemByLinkToken,
  redeemByManualCode,
  type RedemptionCodeBackend,
  type RedemptionCodeRecord,
} from "./caregiver-redemption-store";

class FakeRedemptionBackend implements RedemptionCodeBackend {
  name = "fake";
  private byId = new Map<string, RedemptionCodeRecord>();
  private idByReference = new Map<string, string>();
  private idByLinkHash = new Map<string, string>();
  private nextId = 0;

  async issue(input: {
    tokenId: string;
    reference: string;
    linkTokenHash: string;
    manualCodeHash: string;
    expiresAt: string;
  }): Promise<void> {
    const id = `fake-${this.nextId++}`;
    const record: RedemptionCodeRecord = {
      id,
      tokenId: input.tokenId,
      reference: input.reference,
      linkTokenHash: input.linkTokenHash,
      manualCodeHash: input.manualCodeHash,
      manualCodeAttempts: 0,
      expiresAt: input.expiresAt,
      redeemedAt: null,
    };
    this.byId.set(id, record);
    this.idByReference.set(input.reference, id);
    this.idByLinkHash.set(input.linkTokenHash, id);
  }
  async findByReference(reference: string) {
    const id = this.idByReference.get(reference);
    return id ? this.byId.get(id) ?? null : null;
  }

  async findByLinkTokenHash(hash: string) {
    const id = this.idByLinkHash.get(hash);
    return id ? this.byId.get(id) ?? null : null;
  }

  async markRedeemed(id: string, redeemedAtIso: string): Promise<boolean> {
    const record = this.byId.get(id);
    if (!record || record.redeemedAt) return false;
    record.redeemedAt = redeemedAtIso;
    return true;
  }

  async incrementManualAttempts(id: string): Promise<number> {
    const record = this.byId.get(id);
    if (!record) return 0;
    record.manualCodeAttempts += 1;
    return record.manualCodeAttempts;
  }
}

import { hashCaregiverRedemptionCode } from "../server/caregiver-consent-crypto";

describe("caregiver-redemption-store", () => {
  let backend: FakeRedemptionBackend;

  beforeEach(() => {
    backend = new FakeRedemptionBackend();
    setRedemptionCodeBackendForTest(backend);
  });

  describe("redeemByLinkToken", () => {
    it("redeems a valid, unexpired link token exactly once", async () => {
      const future = new Date(Date.now() + 60_000).toISOString();
      const rawLinkToken = "raw-link-token-abc123";
      await issueRedemptionCode({
        tokenId: "token-1",
        reference: "REF1",
        linkTokenHash: hashCaregiverRedemptionCode(rawLinkToken),
        manualCodeHash: hashCaregiverRedemptionCode("999999"),
        expiresAt: future,
      });

      const first = await redeemByLinkToken(rawLinkToken);
      assert.equal(first.outcome, "redeemed");

      const second = await redeemByLinkToken(rawLinkToken);
      assert.equal(second.outcome, "already_redeemed");
    });

    it("returns not_found for an unknown link token", async () => {
      const result = await redeemByLinkToken("no-such-raw-token");
      assert.equal(result.outcome, "not_found");
    });

    it("returns expired for a link token past its expiry", async () => {
      const past = new Date(Date.now() - 1000).toISOString();
      const rawLinkToken = "raw-link-token-expired";
      await issueRedemptionCode({
        tokenId: "token-2",
        reference: "REF2",
        linkTokenHash: hashCaregiverRedemptionCode(rawLinkToken),
        manualCodeHash: hashCaregiverRedemptionCode("888888"),
        expiresAt: past,
      });

      const result = await redeemByLinkToken(rawLinkToken);
      assert.equal(result.outcome, "expired");
    });
  });

  describe("redeemByManualCode", () => {
  it("redeems a valid manual code found via its reference", async () => {
    const future = new Date(Date.now() + 60_000).toISOString();
    await issueRedemptionCode({
      tokenId: "token-3",
      reference: "REF3",
      linkTokenHash: hashCaregiverRedemptionCode("raw-link-3"),
      manualCodeHash: hashCaregiverRedemptionCode("482913"),
      expiresAt: future,
    });

    const result = await redeemByManualCode("REF3", "482913");
    assert.equal(result.outcome, "redeemed");
  });
  it("counts a wrong guess against the right row via the reference lookup", async () => {
    const future = new Date(Date.now() + 60_000).toISOString();
    await issueRedemptionCode({
      tokenId: "token-4",
      reference: "REF4",
      linkTokenHash: hashCaregiverRedemptionCode("raw-link-4"),
      manualCodeHash: hashCaregiverRedemptionCode("111111"),
      expiresAt: future,
    });

    const wrong = await redeemByManualCode("REF4", "000000");
    assert.equal(wrong.outcome, "mismatch");

    const record = await backend.findByReference("REF4");
    assert.equal(record?.manualCodeAttempts, 1);
  });
  it("locks the code after enough wrong guesses", async () => {
    const future = new Date(Date.now() + 60_000).toISOString();
    await issueRedemptionCode({
      tokenId: "token-5",
      reference: "REF5",
      linkTokenHash: hashCaregiverRedemptionCode("raw-link-5"),
      manualCodeHash: hashCaregiverRedemptionCode("555555"),
      expiresAt: future,
    });

    let lastOutcome = "";
    for (let i = 0; i < 6; i++) {
      const attempt = await redeemByManualCode("REF5", "000000");
      lastOutcome = attempt.outcome;
    }
    assert.equal(lastOutcome, "locked");

    const correctAfterLockout = await redeemByManualCode("REF5", "555555");
    assert.notEqual(correctAfterLockout.outcome, "redeemed");
  });
  it("returns not_found for an unknown reference", async () => {
    const result = await redeemByManualCode("NOPE", "123456");
    assert.equal(result.outcome, "not_found");
  });
});
});
