import type { ReactNode } from "react";

/** Minimal layout — preload capture-critical route, no presentation stack. */
export default function RecordLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <link rel="preconnect" href="/" />
      <link rel="prefetch" href="/record" as="document" />
      {children}
    </>
  );
}
