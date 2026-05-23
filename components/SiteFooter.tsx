import Link from "next/link";

import { TRUST_FOOTER_LINKS } from "@/lib/trust-copy";

export function SiteFooter({ className }: { className?: string }) {
  return (
    <footer className={`pt-12 text-center text-xs text-zinc-600 ${className ?? ""}`}>
      <nav className="flex flex-wrap justify-center gap-x-4 gap-y-2">
        {TRUST_FOOTER_LINKS.map((link) => (
          <Link key={link.href} href={link.href} className="hover:text-zinc-400">
            {link.label}
          </Link>
        ))}
        <Link href="/export" className="hover:text-zinc-400">
          Export
        </Link>
        <Link href="/pricing" className="hover:text-zinc-400">
          Pricing
        </Link>
      </nav>
      <p className="mx-auto mt-4 max-w-md leading-relaxed">
        Reflective mirror only — not therapy, not a diagnosis, not crisis support.
      </p>
    </footer>
  );
}
