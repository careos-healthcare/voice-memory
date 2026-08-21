"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Bell, ChevronRight } from "lucide-react";

import { fadeUp } from "@/lib/motion/variants";
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
      initial="hidden"
      animate="visible"
      variants={fadeUp}
      className="w-full space-y-4 text-left"
    >
      <div className="flex items-center justify-between gap-2 px-1">
        <p className="flex items-center gap-1.5 text-xs tracking-wide text-zinc-500">
          <Bell className="h-3.5 w-3.5" />
          For you right now
        </p>
        <Link
          href="/reminders"
          className="text-xs text-zinc-600 transition-colors hover:text-zinc-400"
        >
          Reminder settings
        </Link>
      </div>

      <ul className="space-y-3">
        {reminders.map((reminder) => (
          <li key={reminder.id}>
            <Link
              href={reminder.href}
              className="group block rounded-xl px-3 py-3 transition-colors hover:bg-white/[0.03]"
            >
              <div className="flex items-center gap-3">
                <div className="min-w-0 flex-1">
                  <p className="text-sm leading-relaxed text-zinc-300/90">
                    {reminder.message}
                  </p>
                </div>
                <span className="flex shrink-0 items-center gap-0.5 text-xs text-zinc-500 transition-colors group-hover:text-zinc-300">
                  {reminder.cta}
                  <ChevronRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
                </span>
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </motion.div>
  );
}
