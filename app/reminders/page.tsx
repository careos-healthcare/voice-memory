"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Bell, BellOff, Smartphone } from "lucide-react";

import { MemoryReminderList } from "@/components/memory/MemoryReminderNote";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  evaluateContextualReminders,
  getPreferredHourLabel,
  REMINDER_COPY_EXAMPLES,
} from "@/lib/contextual-reminders";
import {
  listMemoryReminders,
  MEMORY_REMINDER_COPY_EXAMPLES,
} from "@/lib/memory/memory-reminders";
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
  return (
    <label className="flex cursor-pointer items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.02] p-4 transition-colors hover:bg-white/[0.04]">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="mt-1 h-4 w-4 rounded border-white/20 bg-zinc-900 text-violet-500 focus:ring-violet-500/30"
      />
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-medium text-white">{label}</span>
        <span className="mt-1 block text-xs leading-relaxed text-zinc-500">
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

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Reminder settings
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Reminders
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            In-app reminder placeholders based on your memory patterns — stored on
            this device only. Push notifications are not enabled yet.
          </p>
        </motion.div>

        <Card className="mt-6 border-amber-500/20 bg-amber-500/5">
          <CardContent className="flex items-start gap-3 p-4">
            <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />
            <p className="text-xs leading-relaxed text-amber-100/80">
              These preferences control which reminder cards appear on your home
              screen. They do not send system push notifications — that comes in a
              later release.
            </p>
          </CardContent>
        </Card>

        {loaded ? (
          <div className="mt-6 space-y-6">
            <section className="space-y-3">
              <h2 className="text-sm font-medium text-white">Enable reminders</h2>

              <ToggleRow
                label="Daily reflection"
                description="Suggest a check-in when you have not recorded today."
                checked={prefs.dailyReflection}
                onChange={(dailyReflection) => update({ dailyReflection })}
              />

              <ToggleRow
                label="After stressful entry"
                description="Nudge you to reflect again after a high-intensity entry (7/10+)."
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
                description="Gentle prompt if you have not reflected in three or more days."
                checked={prefs.inactiveThreeDays}
                onChange={(inactiveThreeDays) => update({ inactiveThreeDays })}
              />

              <label className="flex flex-col gap-1.5 rounded-2xl border border-white/10 bg-white/[0.02] p-4">
                <span className="text-sm font-medium text-white">
                  Usual reflection time
                </span>
                <span className="text-xs text-zinc-500">
                  Used for &ldquo;You usually reflect around this time&rdquo; copy
                </span>
                <select
                  value={prefs.preferredReflectionHour}
                  onChange={(e) =>
                    update({
                      preferredReflectionHour: Number(e.target.value),
                    })
                  }
                  className="mt-1 w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20"
                >
                  {Array.from({ length: 24 }, (_, hour) => (
                    <option key={hour} value={hour}>
                      {getPreferredHourLabel(hour)}
                    </option>
                  ))}
                </select>
              </label>
            </section>

            <Card>
              <CardHeader className="pb-2">
                <div className="flex items-center gap-2">
                  <Bell className="h-4 w-4 text-violet-300" />
                  <CardTitle className="text-base">Active on home now</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                {previewCount === 0 ? (
                  <p className="flex items-center gap-2 text-sm text-zinc-500">
                    <BellOff className="h-4 w-4" />
                    No reminder cards match right now.
                  </p>
                ) : (
                  <p className="text-sm text-zinc-300">
                    {previewCount} reminder card
                    {previewCount === 1 ? "" : "s"} would show on the homepage with
                    these settings.
                  </p>
                )}
                <Button asChild variant="secondary" size="sm" className="mt-4">
                  <Link href="/">View homepage</Link>
                </Button>
              </CardContent>
            </Card>

            <section className="space-y-4">
              <div>
                <h2 className="text-sm font-medium text-white">Memory reminders</h2>
                <p className="mt-1 text-xs leading-relaxed text-zinc-500">
                  Sparse nudges from your archive — not daily prompts. Shown on the homepage
                  when something feels worth returning to.
                </p>
              </div>

              {memoryReminders.length === 0 ? (
                <p className="text-sm text-zinc-500">
                  No memory reminders match your archive right now.
                </p>
              ) : (
                <MemoryReminderList reminders={memoryReminders} />
              )}

              <ul className="mt-4 space-y-3">
                {MEMORY_REMINDER_COPY_EXAMPLES.map((example) => (
                  <li
                    key={example.kind}
                    className="rounded-2xl border border-white/10 bg-white/[0.02] p-4"
                  >
                    <p className="text-sm font-medium text-zinc-300">
                      &ldquo;{example.message}&rdquo;
                    </p>
                    <p className="mt-2 text-xs leading-relaxed text-zinc-500">
                      {example.whenShown}
                    </p>
                  </li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="text-sm font-medium text-white">Example copy</h2>
              <p className="mt-1 text-xs text-zinc-500">
                Messages you may see when the moment fits
              </p>
              <ul className="mt-4 space-y-3">
                {REMINDER_COPY_EXAMPLES.map((example) => (
                  <li
                    key={example.kind}
                    className="rounded-2xl border border-white/10 bg-white/[0.02] p-4"
                  >
                    <p className="text-sm font-medium text-violet-200">
                      &ldquo;{example.message}&rdquo;
                    </p>
                    <p className="mt-2 text-xs leading-relaxed text-zinc-500">
                      {example.whenShown}
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        ) : null}
      </div>
    </div>
  );
}
