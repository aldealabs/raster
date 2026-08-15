import Link from "next/link";
import { RasterLockup } from "@/components/brand";
import { docsTabs, getDocPath, getTabForSlug } from "@/lib/navigation";
import { cn } from "@/lib/utils";

export function DocsSidebar({ currentSlug }: { currentSlug: string }) {
  const activeTab = getTabForSlug(currentSlug);

  return (
    <aside className="relative hidden border-r border-border bg-surface before:absolute before:inset-y-0 before:right-full before:w-[50vw] before:bg-surface before:content-[''] lg:block">
      <div className="sticky top-0 h-screen overflow-y-auto px-6 py-7">
        <Link href="/" className="mb-7 block border-b border-border pb-6" aria-label="Raster documentation home">
          <RasterLockup className="w-[126px]" />
          <span className="font-tech mt-2 block text-[10px] uppercase tracking-[0.16em] text-dim">
            Documentation
          </span>
        </Link>
        <div className="mb-7 rounded-md border border-border bg-tint p-2">
          {docsTabs.map((tab) => {
            const Icon = tab.icon;
            const active = tab.id === activeTab.id;
            return (
              <Link
                key={tab.id}
                href={getDocPath(tab.sections[0].items[0].slug)}
                className={cn(
                  "flex items-start gap-3 rounded px-3 py-2.5 text-sm font-normal transition",
                  active ? "bg-tint-strong text-heading" : "text-dim hover:text-foreground",
                )}
              >
                <Icon className="mt-0.5 h-4 w-4 shrink-0" />
                <span>{tab.title}</span>
              </Link>
            );
          })}
        </div>

        <div className="space-y-7">
          {activeTab.sections.map((section) => (
            <section key={section.title}>
              <h2 className="mb-3 font-display text-sm font-semibold text-heading">{section.title}</h2>
              <div className="grid gap-2">
                {section.items.map((item) => {
                  const active = item.slug === currentSlug;
                  return (
                    <Link
                      key={item.slug}
                      href={getDocPath(item.slug)}
                      className={cn(
                        "flex items-center gap-2 text-sm font-normal transition",
                        active
                          ? "font-medium text-accent-text"
                          : "text-muted hover:text-foreground",
                      )}
                    >
                      <span>{item.title}</span>
                      {item.badge ? (
                        <span className="font-tech ml-auto text-[9px] uppercase tracking-wider text-accent-text">
                          {item.badge}
                        </span>
                      ) : null}
                    </Link>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      </div>
    </aside>
  );
}
