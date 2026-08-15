"use client";

import { useEffect, useMemo, useState } from "react";
import type { TocHeading } from "@/lib/docs";
import { cn } from "@/lib/utils";

export function TableOfContents({ headings }: { headings: TocHeading[] }) {
  const headingIds = useMemo(() => headings.map((heading) => heading.id).join("|"), [headings]);
  const [activeId, setActiveId] = useState("");

  useEffect(() => {
    const ids = headingIds.split("|").filter(Boolean);
    const elements = ids
      .map((id) => document.getElementById(id))
      .filter((element): element is HTMLElement => Boolean(element));

    if (!elements.length) return;

    let frame = 0;

    const updateActiveHeading = () => {
      frame = 0;
      const activationOffset = 112;
      let current = elements[0].id;

      for (const element of elements) {
        if (element.getBoundingClientRect().top <= activationOffset) {
          current = element.id;
        } else {
          break;
        }
      }

      setActiveId(current);
    };

    const scheduleUpdate = () => {
      if (frame) return;
      frame = window.requestAnimationFrame(updateActiveHeading);
    };

    scheduleUpdate();
    window.addEventListener("scroll", scheduleUpdate, { passive: true });
    window.addEventListener("resize", scheduleUpdate);
    window.addEventListener("hashchange", scheduleUpdate);

    return () => {
      if (frame) window.cancelAnimationFrame(frame);
      window.removeEventListener("scroll", scheduleUpdate);
      window.removeEventListener("resize", scheduleUpdate);
      window.removeEventListener("hashchange", scheduleUpdate);
    };
  }, [headingIds]);

  return (
    <aside className="relative z-10 hidden min-w-0 border-l border-border bg-background xl:block">
      <div className="sticky top-14 max-h-[calc(100vh-3.5rem)] overflow-y-auto px-6 py-7">
        <p className="mb-4 font-display text-sm font-medium text-heading">On this page</p>
        <nav className="grid gap-2 text-sm font-normal" aria-label="Table of contents">
          {headings.length ? (
            headings.map((heading) => (
              <a
                key={`${heading.id}-${heading.depth}`}
                href={`#${heading.id}`}
                aria-current={activeId === heading.id ? "true" : undefined}
                onClick={() => setActiveId(heading.id)}
                className={cn(
                  "border-l border-border py-0.5 leading-6 transition-colors",
                  heading.depth === 3 ? "pl-4 text-dim" : "pl-3 text-muted",
                  activeId === heading.id
                    ? "border-accent text-heading"
                    : "hover:border-border-strong hover:text-foreground",
                )}
              >
                {heading.title}
              </a>
            ))
          ) : (
            <span className="text-dim">Overview</span>
          )}
        </nav>
      </div>
    </aside>
  );
}
