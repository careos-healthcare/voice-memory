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

type Registry = Partial<Record<PrimaryCtaId, boolean>>;

type HomepagePrimaryCtaContextValue = {
  register: (id: PrimaryCtaId, active: boolean) => void;
  activeWinner: PrimaryCtaId | null;
};

const HomepagePrimaryCtaContext = createContext<HomepagePrimaryCtaContextValue | null>(
  null,
);

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

  const value = useMemo(
    () => ({ register, activeWinner }),
    [register, activeWinner],
  );

  return (
    <HomepagePrimaryCtaContext.Provider value={value}>
      {children}
    </HomepagePrimaryCtaContext.Provider>
  );
}

/**
 * Register a primary CTA claim. Safe without a provider (falls back to `active`).
 * Coordinated claims only run after client hydration to avoid SSR/prerender issues.
 */
export function usePrimaryCtaClaim(id: PrimaryCtaId, active: boolean): boolean {
  const ctx = useContext(HomepagePrimaryCtaContext);
  const hydrated = useClientHydrated();
  const register = ctx?.register;
  const claimActive = hydrated && active;

  useEffect(() => {
    if (!register) return;
    register(id, claimActive);
    return () => register(id, false);
  }, [register, id, claimActive]);

  if (!register) return active;
  if (!hydrated) return false;
  return ctx.activeWinner === id;
}

/** True when any homepage primary CTA owns the surface (e.g. hide habit fallback buttons). */
export function useHomepagePrimaryCtaActive(): boolean {
  const ctx = useContext(HomepagePrimaryCtaContext);
  const hydrated = useClientHydrated();
  if (!ctx || !hydrated) return false;
  return ctx.activeWinner != null;
}
