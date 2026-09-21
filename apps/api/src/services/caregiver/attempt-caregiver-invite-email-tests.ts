import assert from "node:assert/strict";

import { attemptCaregiverInviteEmail } from "@/src/services/caregiver/attempt-caregiver-invite-email";

export async function runCaregiverInviteEmailTests(): Promise<{
  failures: string[];
}> {
  const failures: string[] = [];
  const params = {
    linkToken: "link-1",
    reference: "ref-1",
    manualCode: "code-1",
  };

  try {
    const calls: unknown[] = [];
    const send = async (email: string, sentParams: typeof params) => {
      calls.push({ email, params: sentParams });
    };

    const undefinedResult = await attemptCaregiverInviteEmail({
      email: undefined,
      params,
      send,
    });
    assert.equal(undefinedResult, false);

    const emptyResult = await attemptCaregiverInviteEmail({
      email: "",
      params,
      send,
    });
    assert.equal(emptyResult, false);

    const whitespaceResult = await attemptCaregiverInviteEmail({
      email: "   ",
      params,
      send,
    });
    assert.equal(whitespaceResult, false);

    assert.equal(calls.length, 0);
  } catch (error) {
    failures.push(`absent/empty caregiverEmail failed: ${error}`);
  }

  try {
    const calls: { email: string; params: typeof params }[] = [];
    const send = async (email: string, sentParams: typeof params) => {
      calls.push({ email, params: sentParams });
    };

    const result = await attemptCaregiverInviteEmail({
      email: "sam@example.com",
      params,
      send,
    });

    assert.equal(result, true);
    assert.equal(calls.length, 1);
    assert.equal(calls[0]?.email, "sam@example.com");
    assert.deepEqual(calls[0]?.params, params);
  } catch (error) {
    failures.push(`successful send failed: ${error}`);
  }

  try {
    let called = 0;
    const send = async () => {
      called += 1;
      throw new Error("resend down");
    };

    const result = await attemptCaregiverInviteEmail({
      email: "sam@example.com",
      params,
      send,
    });

    assert.equal(result, false);
    assert.equal(called, 1);
  } catch (error) {
    failures.push(`send throw must not propagate: ${error}`);
  }

  return { failures };
}
