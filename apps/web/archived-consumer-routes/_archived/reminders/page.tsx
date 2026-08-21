"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Bell, BellOff, Smartphone } from "lucide-react";

import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { MemoryReminderList } from "@/archived-components/_archived/memory/MemoryReminderNote";
import { AnimatedReveal } from "@/archived-components/_archived/motion/AnimatedReveal";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  evaluateContextualReminders,
  getPreferredHourLabel,
} from "@/lib/contextual-reminders";
import { listMemoryReminders } from "@/lib/memory/memory-reminders";
import {
  DEFAULT_REMINDER_PREFERENCES,
  getReminderPreferences,
  saveReminderPreferences,
  type ReminderPreferences,
} from "@/lib/reminder-preferences";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MemoryReminder } from "@/types/memory-reminder";

function ToggleRow({
  label,
  description,
  checked,
  onChange,
}: {
  label: string;
  description: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  const id = `reminder-toggle-${label.replace(/\s+/g, "-").toLowerCase()}`;
  return (
    <label
      htmlFor={id}
      className="flex cursor-pointer items-start gap-3 rounded-2xl border border-white/12 bg-white/[0.04] p-4 transition-colors hover:bg-white/[0.06] focus-within:ring-2 focus-within:ring-violet-300 focus-within:ring-offset-2 focus-within:ring-offset-zinc-950"
    >
      <input
        id={id}
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="mt-1 h-4 w-4 rounded border-white/20 bg-zinc-900 text-violet-500 focus:ring-violet-300"
      />
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-medium text-white">{label}</span>
        <span className="mt-1 block text-xs leading-relaxed text-muted">
          {description}
        </span>
      </span>
    </label>
  );
}

export default function RemindersPage() {
  const [prefs, setPrefs] = useState<ReminderPreferences>(
    DEFAULT_REMINDER_PREFERENCES,
  );
  const [loaded, setLoaded] = useState(false);
  const [previewCount, setPreviewCount] = useState(0);
  const [memoryReminders, setMemoryReminders] = useState<MemoryReminder[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const current = getReminderPreferences();
      setPrefs(current);
      setPreviewCount(evaluateContextualReminders(current).length);
      setMemoryReminders(listMemoryReminders(getMemoryEligibleEntries(), 4));
      setLoaded(true);
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const update = (patch: Partial<ReminderPreferences>) => {
    const next = { ...prefs, ...patch };
    setPrefs(next);
    saveReminderPreferences(next);
    setPreviewCount(evaluateContextualReminders(next).length);
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
          <AnimatedReveal>
            <h1 className="text-3xl font-semibold tracking-tight text-white">
              Reminders
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-muted">
              Optional in-app suggestions only — all off by default. Nothing here shames you
              for pausing or counts days to make you feel behind.
            </p>
          </AnimatedReveal>

          <aside
            className="mt-6 rounded-2xl border border-amber-500/25 bg-amber-500/8 p-4"
            aria-label="In-app reminders only"
          >
            <div className="flex items-start gap-3">
              <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-amber-200" aria-hidden />
              <p className="text-xs leading-relaxed text-amber-50">
                These show up in the app only — not as phone notifications yet.
              </p>
            </div>
          </aside>

          {!loaded ? (
            <p className="mt-6 text-sm text-muted" role="status" aria-live="polite">
              Loading reminder settings…
            </p>
          ) : (
            <div className="mt-6 space-y-8">
              <section aria-labelledby="reminder-prefs-heading">
                <h2 id="reminder-prefs-heading" className="sr-only">
                  Reminder preferences
                </h2>
                <div className="space-y-3">
                  <ToggleRow
                    label="Daily reflection"
                    description="Optional suggestion when you have not recorded today."
                    checked={prefs.dailyReflection}
                    onChange={(dailyReflection) => update({ dailyReflection })}
                  />

                  <ToggleRow
                    label="After a heavy reflection"
                    description="Optional note that your words from an intense entry are still here."
                    checked={prefs.afterStressfulEntry}
                    onChange={(afterStressfulEntry) =>
                      update({ afterStressfulEntry })
                    }
                  />

                  <ToggleRow
                    label="Weekly review"
                    description="Point you to your weekly review when enough entries exist."
                    checked={prefs.weeklyReview}
                    onChange={(weeklyReview) => update({ weeklyReview })}
                  />

                  <ToggleRow
                    label="Inactive for 3 days"
                    description="Quiet prompt if you have not reflected in three or more days — no day counts shown."
                    checked={prefs.inactiveThreeDays}
                    onChange={(inactiveThreeDays) => update({ inactiveThreeDays })}
                  />

                  <label
                    htmlFor="reminder-preferred-hour"
                    className="flex flex-col gap-1.5 rounded-2xl border border-white/12 bg-white/[0.04] p-4 focus-within:ring-2 focus-within:ring-violet-300 focus-within:ring-offset-2 focus-within:ring-offset-zinc-950"
                  >
                    <span className="text-sm font-medium text-white">
                      Usual reflection time
                    </span>
                    <span className="text-xs text-muted">
                      We&apos;ll mention this time when suggesting a check-in.
                    </span>
                    <select
                      id="reminder-preferred-hour"
                      value={prefs.preferredReflectionHour}
                      onChange={(e) =>
                        update({
                          preferredReflectionHour: Number(e.target.value),
                        })
                      }
                      className="mt-1 w-full rounded-xl border border-white/12 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-300"
                    >
                      {Array.from({ length: 24 }, (_, hour) => (
                        <option key={hour} value={hour}>
                          {getPreferredHourLabel(hour)}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>
              </section>

              <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center gap-2">
                    <Bell className="h-4 w-4 text-violet-200" aria-hidden />
                    <CardTitle className="text-base" id="home-preview-heading">
                      On home today
                    </CardTitle>
                  </div>
                </CardHeader>
                <CardContent aria-labelledby="home-preview-heading">
                  {previewCount === 0 ? (
                    <p
                      className="flex items-center gap-2 text-sm text-muted"
                      role="status"
                    >
                      <BellOff className="h-4 w-4 shrink-0" aria-hidden />
                      Nothing would show on home right now.
                    </p>
                  ) : (
                    <p className="text-sm text-zinc-200" role="status">
                      You&apos;d see {previewCount} nudge{previewCount === 1 ? "" : "s"}{" "}
                      on home with these settings.
                    </p>
                  )}
                  <Button asChild variant="secondary" size="sm" className="mt-4">
                    <Link href="/">View homepage</Link>
                  </Button>
                </CardContent>
              </Card>

              <section aria-labelledby="memory-reminders-heading">
                <h2
                  id="memory-reminders-heading"
                  className="mb-4 text-sm font-medium text-zinc-200"
                >
                  From your archive
                </h2>
                {memoryReminders.length === 0 ? (
                  <p className="text-sm text-muted" role="status">
                    Nothing to suggest right now.
                  </p>
                ) : (
                  <MemoryReminderList reminders={memoryReminders} />
                )}
              </section>
            </div>
          )}
        </PrimaryMain>
      </div>
    </div>
  );
}
