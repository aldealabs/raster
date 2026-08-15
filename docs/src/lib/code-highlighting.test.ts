import assert from "node:assert/strict";
import test from "node:test";
import rehypeParse from "rehype-parse";
import rehypePrettyCode from "rehype-pretty-code";
import rehypeStringify from "rehype-stringify";
import { unified } from "unified";
import { codeHighlightOptions } from "./code-highlighting.ts";

test("Swift code is tokenized for both Raster themes", async () => {
  const result = await unified()
    .use(rehypeParse, { fragment: true })
    .use(rehypePrettyCode, codeHighlightOptions)
    .use(rehypeStringify)
    .process('<pre><code class="language-swift">let image = MTIImage(cgImage: source)</code></pre>');

  const html = String(result);

  assert.match(html, /data-rehype-pretty-code-figure/);
  assert.match(html, /data-language="swift"/);
  assert.match(html, /--shiki-light:/);
  assert.match(html, /--shiki-dark:/);
  assert.match(html, /<span[^>]+style=/);
});

test("Metal code is tokenized while keeping its language identity", async () => {
  const result = await unified()
    .use(rehypeParse, { fragment: true })
    .use(rehypePrettyCode, codeHighlightOptions)
    .use(rehypeStringify)
    .process(
      '<pre><code class="language-metal">fragment float4 passthrough() { return float4(1); }</code></pre>',
    );

  const html = String(result);

  assert.match(html, /data-language="metal"/);
  assert.match(html, /--shiki-light:/);
  assert.match(html, /--shiki-dark:/);
  assert.match(html, /<span[^>]+style=/);
});

test("migration snippets render as syntax-aware diffs", async () => {
  const result = await unified()
    .use(rehypeParse, { fragment: true })
    .use(rehypePrettyCode, codeHighlightOptions)
    .use(rehypeStringify)
    .process(
      '<pre><code class="language-swift" metastring="diff">-import MetalPetal\n+import Raster\n\n let image: MTIImage</code></pre>',
    );

  const html = String(result);

  assert.match(html, /data-language="swift"/);
  assert.match(html, /data-raster-diff/);
  assert.match(html, /data-diff-line="remove"/);
  assert.match(html, /data-diff-line="add"/);
  assert.match(html, /data-diff-marker="-"/);
  assert.match(html, /data-diff-marker="\+"/);
  assert.match(html, /--shiki-light:/);
  assert.doesNotMatch(html, />-import/);
  assert.doesNotMatch(html, />\+import/);
});
