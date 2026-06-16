import { useEffect } from "react";

import {
  maybeTrackDiscoverAfterFirstBlindSpot,
  maybeTrackReturnedToCheckArchiveView,
} from "@/lib/metrics/evolving-understanding-events";

/** Track discover/theories visits after first working theory (24h return window). */
export function useEvolvingUnderstandingReturnCheck(
  route: "discover" | "theories",
): void {
  useEffect(() => {
    if (route === "discover") {
      maybeTrackDiscoverAfterFirstBlindSpot();
    }
    maybeTrackReturnedToCheckArchiveView(route);
  }, [route]);
}
