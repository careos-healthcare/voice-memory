import { Suspense } from "react";

import { MicCaptureFallback } from "@/archived-components/_archived/capture/MicCaptureFallback";
import { QuickRecordPage } from "@/archived-components/_archived/capture/QuickRecordPage";
import { ReturningArchiveBeliefRedirect } from "@/archived-components/_archived/product/ReturningArchiveBeliefRedirect";

export default function RecordRoutePage() {
  return (
    <Suspense fallback={<MicCaptureFallback />}>
      <ReturningArchiveBeliefRedirect />
      <QuickRecordPage />
    </Suspense>
  );
}
