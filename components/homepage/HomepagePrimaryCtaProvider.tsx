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

import {
  resolvePrimaryCtaWinner,
  type PrimaryCtaId,
} from "@/lib/homepage/primary-cta";

type Registry = Partial<Record<PrimaryCtaId, boolean>>;

type HomepagePrimaryCtaContextValue = {
  canShow: (id: PrimaryCtaId) => boolean;
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

  const canShow = useCallback(
    (id: PrimaryCtaId) => activeWinner === id,
    [activeWinner],
  );

  const value = useMemo(
    () => ({ canShow, register, activeWinner }),
    [canShow, register, activeWinner],
  );

  return (
    <HomepagePrimaryCtaContext.Provider value={value}>
      {children}
    </HomepagePrimaryCtaContext.Provider>
  );
}

/** Register a primary CTA claim; returns whether this id may render its button. */
export function usePrimaryCtaClaim(id: PrimaryCtaId, active: boolean): boolean {
  const ctx = useContext(HomepagePrimaryCtaContext);

  useEffect(() => {
    if (!ctx) return;
    ctx.register(id, active);
    return () => ctx.register(id, false);
  }, [ctx, id, active]);

  if (!ctx) return active;
  return ctx.canShow(id);
}

/** True when any homepage primary CTA owns the surface (e.g. hide habit fallback buttons). */
export function useHomepagePrimaryCtaActive(): boolean {
  const ctx = useContext(HomepagePrimaryCtaContext);
  return ctx?.activeWinner != null;
}
