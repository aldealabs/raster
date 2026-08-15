export const THEME_STORAGE_KEY = "raster-docs-theme";
export const THEME_PREFERENCES = ["system", "light", "dark"] as const;

export type ThemePreference = (typeof THEME_PREFERENCES)[number];
export type ResolvedTheme = "light" | "dark";

export function parseThemePreference(value: unknown): ThemePreference {
  return typeof value === "string"
    && THEME_PREFERENCES.includes(value as ThemePreference)
    ? (value as ThemePreference)
    : "system";
}

export function resolveThemePreference(
  preference: ThemePreference,
  systemPrefersDark: boolean,
): ResolvedTheme {
  return preference === "system"
    ? (systemPrefersDark ? "dark" : "light")
    : preference;
}

export function buildThemeBootstrapScript(): string {
  return [
    "(function(){try{",
    "var key='", THEME_STORAGE_KEY, "';",
    "var preference='system';",
    "try{",
    "var value=window.localStorage.getItem(key);",
    "if(value==='light'||value==='dark'){preference=value;}",
    "}catch(error){}",
    "var resolved=preference==='system'",
    "?(window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light')",
    ":preference;",
    "var root=document.documentElement;",
    "if(preference==='system'){root.removeAttribute('data-theme');}",
    "else{root.setAttribute('data-theme',preference);}",
    "root.classList.toggle('dark',resolved==='dark');",
    "root.style.colorScheme=resolved;",
    "}catch(error){}})();",
  ].join("");
}
