import type { Metadata } from "next";

import { assertInternalPageAccess } from "@/lib/server/internal-page-guard";

export const metadata: Metadata = {
  robots: { index: false, follow: false, nocache: true },
};

export default async function LaunchLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await assertInternalPageAccess();
  return children;
}
