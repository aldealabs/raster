import assert from "node:assert/strict";
import test from "node:test";
import vm from "node:vm";

import {
  buildThemeBootstrapScript,
  parseThemePreference,
  resolveThemePreference,
} from "./theme-preference.ts";

test("invalid stored preferences fall back to the system", () => {
  assert.equal(parseThemePreference("light"), "light");
  assert.equal(parseThemePreference("dark"), "dark");
  assert.equal(parseThemePreference("sepia"), "system");
  assert.equal(parseThemePreference(null), "system");
});

test("system preference resolves from the current color-scheme query", () => {
  assert.equal(resolveThemePreference("system", false), "light");
  assert.equal(resolveThemePreference("system", true), "dark");
  assert.equal(resolveThemePreference("light", true), "light");
  assert.equal(resolveThemePreference("dark", false), "dark");
});

test("bootstrap applies a stored explicit theme before hydration", () => {
  const classes = new Set<string>();
  const attributes = new Map<string, string>();
  const style: Record<string, string> = {};
  const documentElement = {
    classList: {
      toggle(name: string, enabled: boolean) {
        if (enabled) classes.add(name);
        else classes.delete(name);
      },
    },
    removeAttribute(name: string) {
      attributes.delete(name);
    },
    setAttribute(name: string, value: string) {
      attributes.set(name, value);
    },
    style,
  };

  vm.runInNewContext(buildThemeBootstrapScript(), {
    document: { documentElement },
    window: {
      localStorage: { getItem: () => "dark" },
      matchMedia: () => ({ matches: false }),
    },
  });

  assert.equal(attributes.get("data-theme"), "dark");
  assert.equal(classes.has("dark"), true);
  assert.equal(style.colorScheme, "dark");
});
