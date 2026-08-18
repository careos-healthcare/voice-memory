import { cn } from "@/lib/utils";

/** Single primary landmark per route — pairs with #main-content skip link in SiteHeader. */
export function PrimaryMain({
  children,
  className,
  id = "main-content",
}: {
  children: React.ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <main id={id} className={cn(className)}>
      {children}
    </main>
  );
}
