import { Suspense } from "react";

import { MicCaptureFallback } from "@/components/capture/MicCaptureFallback";
import { QuickRecordPage } from "@/components/capture/QuickRecordPage";
import { ReturningArchiveBeliefRedirect } from "@/components/product/ReturningArchiveBeliefRedirect";

export default function RecordRoutePage() {
  return (
    <Suspense fallback={<MicCaptureFallback />}>
      <ReturningArchiveBeliefRedirect />
      <QuickRecordPage />
    </Suspense>
  );
}
