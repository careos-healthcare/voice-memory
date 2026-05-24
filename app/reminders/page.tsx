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
          <h1 className="text-3xl font-semibold tracking-tight text-white">
            Reminders
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Optional in-app suggestions only — all off by default. Nothing here shames you
            for pausing or counts days to make you feel behind.
          </p>
        </motion.div>

        <Card className="mt-6 border-amber-500/20 bg-amber-500/5">
          <CardContent className="flex items-start gap-3 p-4">
            <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />
            <p className="text-xs leading-relaxed text-amber-100/80">
              These show up in the app only — not as phone notifications yet.
            </p>
          </CardContent>
        </Card>

        {loaded ? (
          <div className="mt-6 space-y-6">
            <section className="space-y-3">
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

              <label className="flex flex-col gap-1.5 rounded-2xl border border-white/10 bg-white/[0.02] p-4">
                <span className="text-sm font-medium text-white">
                  Usual reflection time
                </span>
                <span className="text-xs text-zinc-500">
                  We&apos;ll mention this time when suggesting a check-in.
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
                  <CardTitle className="text-base">On home today</CardTitle>
                </div>
              </CardHeader>
              <CardContent>
                {previewCount === 0 ? (
                  <p className="flex items-center gap-2 text-sm text-zinc-500">
                    <BellOff className="h-4 w-4" />
                    Nothing would show on home right now.
                  </p>
                ) : (
                  <p className="text-sm text-zinc-300">
                    You&apos;d see {previewCount} nudge{previewCount === 1 ? "" : "s"} on
                    home with these settings.
                  </p>
                )}
                <Button asChild variant="secondary" size="sm" className="mt-4">
                  <Link href="/">View homepage</Link>
                </Button>
              </CardContent>
            </Card>

            <section className="space-y-4">
              {memoryReminders.length === 0 ? (
                <p className="text-sm text-zinc-500">
                  Nothing to suggest right now.
                </p>
              ) : (
                <MemoryReminderList reminders={memoryReminders} />
              )}
            </section>
          </div>
        ) : null}
      </div>
    </div>
  );
}
