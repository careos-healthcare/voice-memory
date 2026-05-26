import { Suspense } from "react";

import { MicCaptureFallback } from "@/components/capture/MicCaptureFallback";
import { QuickRecordPage } from "@/components/capture/QuickRecordPage";

export default function RecordRoutePage() {
  return (
    <Suspense fallback={<MicCaptureFallback />}>
      <QuickRecordPage />
    </Suspense>
  );
}
