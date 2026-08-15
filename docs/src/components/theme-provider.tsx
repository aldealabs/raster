"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type PropsWithChildren,
} from "react";

import {
  THEME_STORAGE_KEY,
  parseThemePreference,
  resolveThemePreference,
  type ResolvedTheme,
  type ThemePreference,
} from "@/lib/theme-preference";

type ThemeContextValue = {
  preference: ThemePreference;
  resolvedTheme: ResolvedTheme;
  setPreference: (next: ThemePreference) => void;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function applyTheme(preference: ThemePreference, systemPrefersDark: boolean) {
  const resolvedTheme = resolveThemePreference(preference, systemPrefersDark);
  const root = document.documentElement;
  if (preference === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", preference);
  root.classList.toggle("dark", resolvedTheme === "dark");
  root.style.colorScheme = resolvedTheme;
  return resolvedTheme;
}

function readStoredThemePreference(): ThemePreference {
  try {
    return parseThemePreference(window.localStorage.getItem(THEME_STORAGE_KEY));
  } catch {
    return "system";
  }
}

function writeStoredThemePreference(preference: ThemePreference) {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, preference);
  } catch {
    // Theme changes still apply for this session when persistence is unavailable.
  }
}

export function ThemeProvider({ children }: PropsWithChildren) {
  const [preference, setPreferenceState] = useState<ThemePreference>("system");
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>("dark");

  const setPreference = useCallback((next: ThemePreference) => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    writeStoredThemePreference(next);
    setPreferenceState(next);
    setResolvedTheme(applyTheme(next, media.matches));
  }, []);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const sync = () => {
      const next = readStoredThemePreference();
      setPreferenceState(next);
      setResolvedTheme(applyTheme(next, media.matches));
    };
    const handleStorage = (event: StorageEvent) => {
      if (event.key === THEME_STORAGE_KEY) sync();
    };

    sync();
    media.addEventListener("change", sync);
    window.addEventListener("storage", handleStorage);
    return () => {
      media.removeEventListener("change", sync);
      window.removeEventListener("storage", handleStorage);
    };
  }, []);

  const value = useMemo(
    () => ({ preference, resolvedTheme, setPreference }),
    [preference, resolvedTheme, setPreference],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("useTheme must be used within ThemeProvider");
  return value;
}
