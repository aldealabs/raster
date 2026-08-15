import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { validateDocs } from "./validate-docs.mjs";

function fixture({
  navigation = 'const items = [{ title: "Overview", slug: "start/overview" }];',
  content = `---
title: Overview
description: A valid page.
---

## Contract

Read [this section](/docs/start/overview#contract).
`,
} = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "raster-docs-validator."));
  const contentRoot = path.join(root, "content/docs");
  const navigationFile = path.join(root, "navigation.ts");
  fs.mkdirSync(path.join(contentRoot, "start"), { recursive: true });
  fs.writeFileSync(path.join(contentRoot, "start/overview.mdx"), content);
  fs.writeFileSync(navigationFile, navigation);
  return {
    root,
    contentRoot,
    navigationFile,
    cleanup: () => fs.rmSync(root, { recursive: true, force: true }),
  };
}

test("accepts a complete content graph", () => {
  const value = fixture();
  try {
    assert.deepEqual(validateDocs(value), []);
  } finally {
    value.cleanup();
  }
});

test("rejects orphaned and missing navigation pages", () => {
  const value = fixture({
    navigation: 'const items = [{ slug: "start/missing" }];',
  });
  try {
    const errors = validateDocs(value);
    assert(errors.includes("start/overview: content page is missing from navigation"));
    assert(errors.includes("start/missing: navigation entry has no content page"));
  } finally {
    value.cleanup();
  }
});

test("rejects duplicate slugs", () => {
  const value = fixture({
    navigation: 'const items = [{ slug: "start/overview" }, { slug: "start/overview" }];',
  });
  try {
    assert(
      validateDocs(value).includes("Navigation contains duplicate slug: start/overview"),
    );
  } finally {
    value.cleanup();
  }
});

test("rejects broken links and heading fragments", () => {
  const value = fixture({
    content: `---
title: Overview
description: Broken links.
---

## Contract

[Missing page](/docs/start/nope)
[Missing heading](/docs/start/overview#nope)
`,
  });
  try {
    const errors = validateDocs(value);
    assert(errors.includes("start/overview: broken documentation link /docs/start/nope"));
    assert(
      errors.includes(
        "start/overview: missing heading in documentation link /docs/start/overview#nope",
      ),
    );
  } finally {
    value.cleanup();
  }
});

test("rejects incomplete frontmatter and stale module imports", () => {
  const value = fixture({
    content: `---
title: ""
---

import MetalPetal
`,
  });
  try {
    const errors = validateDocs(value);
    assert(errors.includes("start/overview: frontmatter requires a non-empty title"));
    assert(errors.includes("start/overview: frontmatter requires a non-empty description"));
    assert(errors.includes("start/overview: uses a MetalPetal import outside the migration guide"));
  } finally {
    value.cleanup();
  }
});
