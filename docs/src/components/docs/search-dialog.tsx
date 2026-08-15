"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { Search, X } from "lucide-react";
import type { SearchRecord } from "@/lib/docs";
import { cn } from "@/lib/utils";

function scoreResult(doc: SearchRecord, query: string) {
  const normalized = query.trim().toLowerCase();
  if (!normalized) return 0;
  const terms = normalized.split(/\s+/);
  const haystack = doc.text.toLowerCase();
  let score = 0;

  for (const term of terms) {
    if (doc.title.toLowerCase().includes(term)) score += 10;
    if (doc.sectionTitle.toLowerCase().includes(term)) score += 4;
    if (doc.description.toLowerCase().includes(term)) score += 3;
    if (haystack.includes(term)) score += 1;
  }

  return score;
}

function makeExcerpt(doc: SearchRecord, query: string) {
  const text = doc.text.replace(/\s+/g, " ");
  const term = query.trim().split(/\s+/)[0]?.toLowerCase();
  if (!term) return doc.description;
  const index = text.toLowerCase().indexOf(term);
  if (index < 0) return doc.description;
  const start = Math.max(0, index - 80);
  return `${start > 0 ? "..." : ""}${text.slice(start, start + 190)}...`;
}

export function SearchDialog({ records }: { records: SearchRecord[] }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setOpen(true);
      }
      if (event.key === "Escape") {
        setOpen(false);
      }
    };

    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  useEffect(() => {
    if (!open) return;
    const id = window.setTimeout(() => inputRef.current?.focus(), 40);
    return () => window.clearTimeout(id);
  }, [open]);

  const results = useMemo(() => {
    if (!query.trim()) return [];
    return records
      .map((record) => ({ record, score: scoreResult(record, query) }))
      .filter((result) => result.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 8);
  }, [query, records]);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="hidden h-10 items-center gap-2 rounded-full border border-border bg-chrome px-3 text-sm font-normal text-dim backdrop-blur-md transition hover:border-border-strong hover:text-foreground lg:flex"
      >
        <Search className="h-4 w-4" />
        <span>Search</span>
        <kbd className="ml-1 rounded border border-border bg-tint px-1.5 py-0.5 text-[11px] text-dim">
          ⌘ K
        </kbd>
      </button>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label="Search"
        className="inline-flex h-10 w-10 touch-manipulation items-center justify-center rounded-full border border-border bg-chrome text-dim backdrop-blur-md hover:border-border-strong hover:text-foreground active:bg-tint-strong lg:hidden"
      >
        <Search className="h-4 w-4" />
      </button>

      {open ? (
        <div
          className="fixed inset-0 z-50 bg-overlay backdrop-blur-[2px]"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) setOpen(false);
          }}
        >
          <div className="mx-auto mt-14 max-h-[calc(100vh-7rem)] w-[min(640px,calc(100vw-2rem))] overflow-hidden rounded-lg border border-border-strong bg-background shadow-2xl">
            <div className="p-5">
              <label className="flex h-14 items-center gap-3 rounded-lg border-2 border-heading bg-panel-strong px-4 text-heading">
                <Search className="h-5 w-5 shrink-0 text-dim" />
                <input
                  ref={inputRef}
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search Raster docs"
                  className="min-w-0 flex-1 bg-transparent text-base font-normal outline-none placeholder:text-dim"
                />
                <button
                  type="button"
                  aria-label="Clear search"
                  onClick={() => (query ? setQuery("") : setOpen(false))}
                  className="text-dim hover:text-foreground"
                >
                  <X className="h-6 w-6" />
                </button>
              </label>
            </div>
            <div className="max-h-[calc(100vh-13rem)] overflow-y-auto px-5 pb-5">
              {query.trim() ? (
                <p className="mb-4 text-sm font-normal text-heading">
                  {results.length} result{results.length === 1 ? "" : "s"} for {query}
                </p>
              ) : (
                <p className="mb-4 text-sm font-normal text-muted">
                  Search the guides, framework pages, API reference, and internals.
                </p>
              )}
              <div className="space-y-4">
                {results.map(({ record }) => (
                  <Link
                    key={record.slug}
                    href={record.href}
                    onClick={() => setOpen(false)}
                    className="block overflow-hidden rounded-md border border-border bg-panel transition hover:border-accent"
                  >
                    <div className="border-b border-border bg-tint px-4 py-3">
                      <p className="font-display text-base font-medium text-heading">{record.title}</p>
                        <p className="mt-1 text-xs font-normal text-accent-text">
                        {record.tabTitle} / {record.sectionTitle}
                      </p>
                    </div>
                    <div className="px-4 py-3">
                      <p className={cn("line-clamp-3 text-sm font-normal leading-6 text-muted")}>
                        {makeExcerpt(record, query)}
                      </p>
                    </div>
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
