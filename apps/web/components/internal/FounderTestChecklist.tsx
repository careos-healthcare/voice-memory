"use client";

import type { FounderTestChecklistItem } from "@/types/founder-test";

interface FounderTestChecklistProps {
  items: FounderTestChecklistItem[];
  onToggle: (itemId: string, completed: boolean) => void;
}

export function FounderTestChecklist({ items, onToggle }: FounderTestChecklistProps) {
  return (
    <ul className="space-y-2">
      {items.map((item) => (
        <li key={item.id} className="flex items-start gap-3 text-sm">
          <input
            type="checkbox"
            checked={item.completed}
            onChange={(e) => onToggle(item.id, e.target.checked)}
            className="mt-1 h-4 w-4 rounded border-white/20 bg-zinc-900"
          />
          <span className={item.completed ? "text-zinc-400 line-through" : "text-zinc-200"}>
            {item.label}
          </span>
        </li>
      ))}
    </ul>
  );
}
