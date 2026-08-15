"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { RasterLockup } from "@/components/brand";
import { docsTabs, getDocPath, getTabForSlug } from "@/lib/navigation";
import { cn } from "@/lib/utils";

export function MobileDocsMenu({ currentSlug }: { currentSlug?: string }) {
  const [open, setOpen] = useState(false);
  const activeTab = useMemo(
    () => (currentSlug ? getTabForSlug(currentSlug) : null),
    [currentSlug],
  );

  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="Open documentation menu"
        className="inline-flex h-10 w-10 touch-manipulation items-center justify-center rounded-full border border-border bg-chrome text-dim backdrop-blur-md transition hover:border-border-strong hover:text-foreground active:bg-tint-strong lg:hidden"
      >
        <Menu className="h-4 w-4" />
      </button>
      {open ? (
        <div className="fixed inset-0 z-50 bg-overlay backdrop-blur-[2px] lg:hidden">
          <div className="h-full w-[min(360px,calc(100vw-2rem))] overflow-y-auto border-r border-border bg-background p-5 shadow-2xl">
            <div className="mb-5 flex items-center justify-between">
              <Link
                href="/"
                onClick={() => setOpen(false)}
                className="block w-[112px]"
              >
                <RasterLockup className="w-[112px]" />
              </Link>
              <button
                type="button"
                onClick={() => setOpen(false)}
                aria-label="Close documentation menu"
                className="inline-flex h-9 w-9 items-center justify-center rounded-full border border-border text-dim hover:text-foreground"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="rounded-md border border-border bg-tint p-2">
              {docsTabs.map((tab) => {
                const Icon = tab.icon;
                const active = activeTab?.id === tab.id;
                return (
                  <Link
                    key={tab.id}
                    href={getDocPath(tab.sections[0].items[0].slug)}
                    onClick={() => setOpen(false)}
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

            {activeTab ? (
              <div className="mt-7 space-y-7">
                {activeTab.sections.map((section) => (
                  <section key={section.title}>
                    <h2 className="mb-3 font-display text-sm font-medium text-heading">{section.title}</h2>
                    <div className="grid gap-2">
                      {section.items.map((item) => (
                        <Link
                          key={item.slug}
                          href={getDocPath(item.slug)}
                          onClick={() => setOpen(false)}
                          className={cn(
                            "flex items-center gap-2 text-sm font-normal transition",
                            item.slug === currentSlug
                              ? "text-accent-text"
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
                      ))}
                    </div>
                  </section>
                ))}
              </div>
            ) : null}
          </div>
        </div>
      ) : null}
    </>
  );
}
