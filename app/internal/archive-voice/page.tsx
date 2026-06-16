import Link from "next/link";

import { ArchiveVoiceConsistencyPanel } from "@/components/internal/ArchiveVoiceConsistencyPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildArchiveVoiceConsistencyReport } from "@/lib/archive/archive-voice-report";

export default function ArchiveVoiceInternalPage() {
  const report = buildArchiveVoiceConsistencyReport();

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Archive voice</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Archive Voice Consistency
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Thoughtful, observational copy on intelligence surfaces — without coach, cheerleader, or
            therapy framing.
          </p>
        </header>

        <div className="mt-6">
          <ArchiveVoiceConsistencyPanel report={report} />
        </div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/emotional-integrity" className="text-violet-300 hover:text-violet-200">
            Emotional integrity →
          </Link>
          <Link href="/internal/archive-simplicity" className="text-zinc-500 hover:text-zinc-300">
            Archive simplicity →
          </Link>
        </div>
      </div>
    </div>
  );
}
