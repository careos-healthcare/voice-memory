"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Bell, ChevronRight } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";
import {
  evaluateContextualReminders,
  type ContextualReminder,
} from "@/lib/contextual-reminders";

export function ContextualReminderCards() {
  const [reminders, setReminders] = useState<ContextualReminder[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReminders(evaluateContextualReminders().slice(0, 3));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  if (reminders.length === 0) return null;

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      className="w-full space-y-2 text-left"
    >
      <div className="flex items-center justify-between gap-2 px-1">
        <p className="flex items-center gap-1.5 text-xs font-medium uppercase tracking-wider text-violet-300/90">
          <Bell className="h-3.5 w-3.5" />
          For you right now
        </p>
        <Link
          href="/reminders"
          className="text-xs text-zinc-500 transition-colors hover:text-violet-300"
        >
          Reminder settings
        </Link>
      </div>

      {reminders.map((reminder) => (
        <Link key={reminder.id} href={reminder.href} className="group block">
          <Card className="border-violet-400/20 bg-violet-500/5 transition-colors hover:border-violet-400/35 hover:bg-violet-500/10">
            <CardContent className="flex items-center gap-3 p-4">
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-violet-200/90">
                  {reminder.title}
                </p>
                <p className="mt-0.5 text-sm text-zinc-200">{reminder.message}</p>
              </div>
              <span className="flex shrink-0 items-center gap-0.5 text-xs text-violet-300">
                {reminder.cta}
                <ChevronRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
              </span>
            </CardContent>
          </Card>
        </Link>
      ))}
    </motion.div>
  );
}
