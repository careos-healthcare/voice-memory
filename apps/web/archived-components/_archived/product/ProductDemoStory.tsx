import { PRODUCT_DEMO_STORY } from "@/lib/product/product-clarity-copy";

export function ProductDemoStory({ className = "" }: { className?: string }) {
  return (
    <div
      className={`rounded-2xl border border-dashed border-white/10 bg-black/20 px-4 py-4 text-left ${className}`}
      data-testid="product-demo-story"
    >
      <p className="text-[10px] uppercase tracking-wider text-zinc-600">
        {PRODUCT_DEMO_STORY.label}
      </p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400/95">{PRODUCT_DEMO_STORY.body}</p>
      <p className="mt-2 text-xs leading-relaxed text-zinc-600">
        {PRODUCT_DEMO_STORY.disclaimer}
      </p>
    </div>
  );
}
