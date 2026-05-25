"use client";

import { useEffect, useState } from "react";

/** True after mount — use before reading localStorage or other browser-only state in render. */
export function useClientHydrated(): boolean {
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setHydrated(true);
  }, []);

  return hydrated;
}
