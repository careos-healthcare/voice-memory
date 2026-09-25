import { Resend } from "resend";

import { waitlistFromAddress, waitlistUnsubscribeUrl } from "@/lib/waitlist/signup";

export function waitlistConfirmationText(unsubscribeUrl: string): string {
  return `You're on the Thoughtprint waitlist.

We'll write when you can start a private voice journal on your phone.

Unsubscribe: ${unsubscribeUrl}`;
}

export async function sendWaitlistConfirmation(
  email: string,
  unsubscribeUrl: string,
): Promise<void> {
  if (process.env.NODE_ENV !== "production") return;

  const listUnsubscribe = unsubscribeUrl;
  try {
    const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
    if (!apiKey) {
      throw new Error("RESEND_API_KEY is not configured.");
    }
    const resend = new Resend(apiKey);
    const { error } = await resend.emails.send({
      from: waitlistFromAddress(),
      to: [email],
      subject: "You're on the Thoughtprint waitlist",
      text: waitlistConfirmationText(unsubscribeUrl),
      headers: {
        "List-Unsubscribe": `<${listUnsubscribe}>`,
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
      },
    });
    if (error) {
      console.error("Resend rejected the waitlist email.", error.message);
    }
  } catch (error) {
    console.error("Resend failed to send the waitlist email.", error);
  }
}

export { waitlistUnsubscribeUrl };
