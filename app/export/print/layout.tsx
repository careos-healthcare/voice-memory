import type { Metadata } from "next";

import "../print.css";

export const metadata: Metadata = {
  title: "ArchiveMe — Print report",
};

export default function ExportPrintLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
