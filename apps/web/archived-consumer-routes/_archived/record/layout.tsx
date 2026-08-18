import type { ReactNode } from "react";

import { RecordFullscreenCapture } from "@/components/capture/RecordFullscreenCapture";

/** Record route — fullscreen capture, no site chrome. */
export default function RecordLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <link rel="prefetch" href="/record" as="document" />
      <RecordFullscreenCapture>{children}</RecordFullscreenCapture>
    </>
  );
}
