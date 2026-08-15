"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { cn } from "@/lib/utils";

type TabsContextValue = {
  value: string;
  setValue: (value: string) => void;
};

const TabsContext = createContext<TabsContextValue | null>(null);

export function Tabs({
  defaultValue,
  syncKey,
  children,
}: {
  defaultValue: string;
  syncKey?: string;
  children: React.ReactNode;
}) {
  const storageKey = syncKey ? `raster-docs-tab:${syncKey}` : null;
  const [value, setValue] = useState(defaultValue);

  useEffect(() => {
    if (!storageKey) return;
    let cancelled = false;
    const frame = window.requestAnimationFrame(() => {
      const stored = window.localStorage.getItem(storageKey);
      if (!cancelled && stored) setValue(stored);
    });
    return () => {
      cancelled = true;
      window.cancelAnimationFrame(frame);
    };
  }, [storageKey]);

  const contextValue = useMemo<TabsContextValue>(
    () => ({
      value,
      setValue: (nextValue) => {
        setValue(nextValue);
        if (storageKey) window.localStorage.setItem(storageKey, nextValue);
      },
    }),
    [storageKey, value],
  );

  return (
    <TabsContext.Provider value={contextValue}>
      <div className="my-5">{children}</div>
    </TabsContext.Provider>
  );
}

export function TabsList({ children }: { children: React.ReactNode }) {
  return (
    <div
      role="tablist"
      className="mb-3 flex gap-5 border-b border-border text-sm font-normal text-muted"
    >
      {children}
    </div>
  );
}

export function TabsTrigger({
  value,
  children,
}: {
  value: string;
  children: React.ReactNode;
}) {
  const context = useContext(TabsContext);
  if (!context) throw new Error("TabsTrigger must be used inside Tabs");
  const selected = context.value === value;

  return (
    <button
      type="button"
      role="tab"
      aria-selected={selected}
      onClick={() => context.setValue(value)}
      className={cn(
        "-mb-px border-b px-0 pb-2 transition-colors",
        selected
          ? "border-accent text-heading"
          : "border-transparent hover:border-border-strong hover:text-foreground",
      )}
    >
      {children}
    </button>
  );
}

export function TabsContent({
  value,
  children,
}: {
  value: string;
  children: React.ReactNode;
}) {
  const context = useContext(TabsContext);
  if (!context) throw new Error("TabsContent must be used inside Tabs");
  if (context.value !== value) return null;
  return <div role="tabpanel">{children}</div>;
}
