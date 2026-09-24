"use client";

import { useState } from "react";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setMessage(null);
    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const payload = (await response.json()) as { ok?: boolean; error?: string };
      if (!response.ok || !payload.ok) {
        setMessage(payload.error ?? "Could not save that email. Try again.");
        return;
      }
      setEmail("");
      setMessage("You're on the list. Check your email for a confirmation.");
    } catch {
      setMessage("Could not save that email. Try again.");
    } finally {
      setPending(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
      <label className="sr-only" htmlFor="waitlist-email">
        Email address
      </label>
      <input
        id="waitlist-email"
        name="email"
        type="email"
        autoComplete="email"
        required
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        placeholder="you@example.com"
        className="w-full rounded-full border border-white/15 bg-zinc-900 px-5 py-3 text-white placeholder:text-zinc-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/60"
      />
      <button
        type="submit"
        disabled={pending}
        className="rounded-full bg-violet-600 px-5 py-3 text-sm font-medium text-white transition-colors hover:bg-violet-500 disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/60"
      >
        {pending ? "Joining…" : "Join the waitlist"}
      </button>
      {message ? (
        <p className="basis-full text-sm text-zinc-300" role="status">
          {message}
        </p>
      ) : null}
    </form>
  );
}
