"use client";

import { useState, type ReactNode } from "react";
import { ChevronDown } from "lucide-react";

import { Button } from "@/components/ui/button";

interface SeeMorePanelProps {
  children: ReactNode;
  label?: string;
  defaultOpen?: boolean;
  className?: string;
}

export function SeeMorePanel({
  children,
  label = "See more",
  defaultOpen = false,
  className,
}: SeeMorePanelProps) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className={className}>
      {!open ? (
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="mt-2 w-full text-zinc-500 hover:text-zinc-300"
          onClick={() => setOpen(true)}
        >
          {label}
          <ChevronDown className="ml-1 h-4 w-4" />
        </Button>
      ) : (
        <div className="mt-8 space-y-8">{children}</div>
      )}
    </div>
  );
}
