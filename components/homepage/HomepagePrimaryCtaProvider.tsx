"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import {
  resolvePrimaryCtaWinner,
  type PrimaryCtaId,
} from "@/lib/homepage/primary-cta";

type RegisterFn = (id: PrimaryCtaId, active: boolean) => void;
type Registry = Partial<Record<PrimaryCtaId, boolean>>;

/** Stable register fn — does not change when the winner changes. */
const HomepagePrimaryCtaRegisterContext = createContext<RegisterFn | null>(null);

/** Winner id only — consumers that need display gating subscribe here. */
const HomepagePrimaryCtaWinnerContext = createContext<PrimaryCtaId | null>(null);

export function HomepagePrimaryCtaProvider({ children }: { children: ReactNode }) {
  const [registry, setRegistry] = useState<Registry>({});

  const register = useCallback((id: PrimaryCtaId, active: boolean) => {
    setRegistry((prev) => {
      if (!!prev[id] === active) return prev;
      const next = { ...prev };
      if (active) next[id] = true;
      else delete next[id];
      return next;
    });
  }, []);

  const activeWinner = useMemo(() => resolvePrimaryCtaWinner(registry), [registry]);

  return (
    <HomepagePrimaryCtaRegisterContext.Provider value={register}>
      <HomepagePrimaryCtaWinnerContext.Provider value={activeWinner}>
        {children}
      </HomepagePrimaryCtaWinnerContext.Provider>
    </HomepagePrimaryCtaRegisterContext.Provider>
  );
}

/**
 * Register a primary CTA claim. Safe without a provider (falls back to `active`).
 * Coordinated claims only run after client hydration to avoid SSR/prerender issues.
 */
export function usePrimaryCtaClaim(id: PrimaryCtaId, active: boolean): boolean {
  const register = useContext(HomepagePrimaryCtaRegisterContext);
  const activeWinner = useContext(HomepagePrimaryCtaWinnerContext);
  const hydrated = useClientHydrated();
  const claimActive = hydrated && active;

  useEffect(() => {
    if (!register) return;
    register(id, claimActive);
    return () => register(id, false);
  }, [register, id, claimActive]);

  if (!register) return active;
  if (!hydrated) return false;
  return activeWinner === id;
}

/** True when any homepage primary CTA owns the surface (e.g. hide habit fallback buttons). */
export function useHomepagePrimaryCtaActive(): boolean {
  const activeWinner = useContext(HomepagePrimaryCtaWinnerContext);
  const hydrated = useClientHydrated();
  if (!hydrated) return false;
  return activeWinner != null;
}
