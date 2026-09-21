export type CaregiverInviteEmailParams = {
  linkToken: string;
  reference: string;
  manualCode: string;
};

export type SendCaregiverInviteEmailFn = (
  email: string,
  params: CaregiverInviteEmailParams,
) => Promise<unknown>;

/**
 * Opt-in caregiver invite send. Failures never throw: the grant already
 * persisted, so a mail outage must not fail the issue request.
 *
 * `send` defaults to the real Resend sender, loaded only when omitted so
 * tests can stay network-free.
 */
export async function attemptCaregiverInviteEmail(options: {
  email: string | undefined;
  params: CaregiverInviteEmailParams;
  send?: SendCaregiverInviteEmailFn;
  onError?: (error: unknown) => void;
}): Promise<boolean> {
  const email = options.email?.trim() ?? "";
  if (!email) {
    return false;
  }

  const send =
    options.send ??
    (await import("@/lib/email/send-caregiver-invite-email"))
      .sendCaregiverInviteEmail;

  try {
    await send(email, options.params);
    return true;
  } catch (error) {
    options.onError?.(error);
    return false;
  }
}
