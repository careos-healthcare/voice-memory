import Link from "next/link";
import { Lock } from "lucide-react";

import { DEVICE_PRIVACY_LINE } from "@/lib/product-copy";
import { cn } from "@/lib/utils";

export function PrivacyNotice({
  className,
  showPolicyLink = true,
}: {
  className?: string;
  showPolicyLink?: boolean;
}) {
  return (
    <p className={cn("flex items-start gap-2 text-xs leading-relaxed text-muted", className)}>
      <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0 text-muted" aria-hidden />
      <span>
        {DEVICE_PRIVACY_LINE}
        {showPolicyLink ? (
          <>
            {" "}
            <Link
              href="/privacy"
              className="text-violet-200 underline underline-offset-2 hover:text-violet-100"
            >
              Privacy
            </Link>
          </>
        ) : null}
      </span>
    </p>
  );
}
