"use client";

import { Monitor, Moon, Sun } from "lucide-react";
import { useTheme } from "@/components/theme-provider";
import type { ThemePreference } from "@/lib/theme-preference";

const LABELS: Record<ThemePreference, string> = {
  system: "System",
  light: "Light",
  dark: "Dark",
};

const NEXT_PREFERENCE: Record<ThemePreference, ThemePreference> = {
  system: "light",
  light: "dark",
  dark: "system",
};

const ICONS = {
  system: Monitor,
  light: Sun,
  dark: Moon,
};

export function ThemeToggle() {
  const { preference, setPreference } = useTheme();
  const next = NEXT_PREFERENCE[preference];
  const Icon = ICONS[preference];

  return (
    <button
      type="button"
      onClick={() => setPreference(next)}
      aria-label={`Theme: ${LABELS[preference]}. Switch to ${LABELS[next].toLowerCase()}`}
      title={`Theme: ${LABELS[preference]}`}
      className="inline-flex h-10 w-10 touch-manipulation items-center justify-center rounded-full border border-border bg-chrome text-dim backdrop-blur-md transition hover:border-border-strong hover:text-foreground active:bg-tint-strong"
    >
      <Icon className="h-4 w-4" />
    </button>
  );
}
