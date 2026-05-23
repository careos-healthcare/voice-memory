import type { Metadata } from "next";

import "../print.css";

export const metadata: Metadata = {
  title: "VoiceMemory — Print report",
};

export default function ExportPrintLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
