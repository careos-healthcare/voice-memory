import { Suspense } from "react";

import { QuickRecordPage } from "@/components/capture/QuickRecordPage";

export default function RecordRoutePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen-mobile bg-zinc-950 pb-safe">
          <div className="mx-auto flex min-h-screen-mobile max-w-xl flex-col px-4 pb-10 sm:px-6">
            <main className="flex flex-1 flex-col justify-center" aria-busy="true" />
          </div>
        </div>
      }
    >
      <QuickRecordPage />
    </Suspense>
  );
}
