import type { Metadata } from "next";

import { FounderInternalNav } from "@/components/internal/FounderInternalNav";
import { assertInternalPageAccess } from "@/lib/server/internal-page-guard";

export const metadata: Metadata = {
  title: "Internal",
  robots: { index: false, follow: false, nocache: true },
};

export default async function InternalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await assertInternalPageAccess();
  return (
    <div data-internal-surface="true" className="min-h-screen bg-zinc-950 text-zinc-100">
      <FounderInternalNav />
      {children}
    </div>
  );
}
