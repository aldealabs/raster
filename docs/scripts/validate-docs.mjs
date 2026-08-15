import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import matter from "gray-matter";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(scriptDirectory, "..");

function collectFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return collectFiles(entryPath);
    return entryPath.endsWith(".mdx") ? [entryPath] : [];
  });
}

function slugifyHeading(value) {
  return value
    .toLowerCase()
    .replace(/`([^`]+)`/g, "$1")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");
}

function headingsFor(content) {
  return [...content.matchAll(/^(##|###)\s+(.+)$/gm)].map((match) =>
    slugifyHeading(match[2].replace(/\s+\{#.*?\}\s*$/, "").trim()),
  );
}

function linksFor(content) {
  return [...content.matchAll(/(?<!!)\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)].map(
    (match) => match[1],
  );
}

function navigationSlugs(source) {
  return [...source.matchAll(/\bslug:\s*"([^"]+)"/g)].map((match) => match[1]);
}

function duplicateValues(values) {
  const seen = new Set();
  const duplicates = new Set();
  for (const value of values) {
    if (seen.has(value)) duplicates.add(value);
    seen.add(value);
  }
  return [...duplicates].sort();
}

function documentTarget(link, sourceSlug) {
  const [withoutQuery] = link.split("?");
  const [pathname, hash = ""] = withoutQuery.split("#");

  if (pathname === "/docs" || pathname === "/docs/") {
    return { slug: "start/overview", hash };
  }
  if (pathname.startsWith("/docs/")) {
    return { slug: pathname.slice("/docs/".length).replace(/\/$/, ""), hash };
  }
  if (pathname.endsWith(".mdx")) {
    const sourceDirectory = path.posix.dirname(sourceSlug);
    const slug = path.posix
      .normalize(path.posix.join(sourceDirectory, pathname))
      .replace(/\.mdx$/, "");
    return { slug, hash };
  }
  return null;
}

export function validateDocs({ contentRoot, navigationFile }) {
  const errors = [];
  if (!fs.existsSync(navigationFile)) {
    return [`Navigation file does not exist: ${navigationFile}`];
  }

  const navSlugs = navigationSlugs(fs.readFileSync(navigationFile, "utf8"));
  for (const slug of duplicateValues(navSlugs)) {
    errors.push(`Navigation contains duplicate slug: ${slug}`);
  }

  const docs = new Map();
  for (const file of collectFiles(contentRoot)) {
    const slug = path.relative(contentRoot, file).split(path.sep).join("/").replace(/\.mdx$/, "");
    const source = fs.readFileSync(file, "utf8");
    let parsed;
    try {
      parsed = matter(source);
    } catch (error) {
      errors.push(`${slug}: invalid frontmatter (${error.message})`);
      continue;
    }

    if (typeof parsed.data.title !== "string" || !parsed.data.title.trim()) {
      errors.push(`${slug}: frontmatter requires a non-empty title`);
    }
    if (typeof parsed.data.description !== "string" || !parsed.data.description.trim()) {
      errors.push(`${slug}: frontmatter requires a non-empty description`);
    }

    const headings = headingsFor(parsed.content);
    for (const heading of duplicateValues(headings)) {
      errors.push(`${slug}: duplicate generated heading id #${heading}`);
    }

    if (
      slug !== "start/migrating-from-metalpetal" &&
      /^\s*(?:import\s+MetalPetal\b|@import\s+MetalPetal\b|#(?:import|include)\s*[<"]MetalPetal\/)/m.test(
        parsed.content,
      )
    ) {
      errors.push(`${slug}: uses a MetalPetal import outside the migration guide`);
    }

    docs.set(slug, { headings: new Set(headings), links: linksFor(parsed.content) });
  }

  const navSet = new Set(navSlugs);
  for (const slug of docs.keys()) {
    if (!navSet.has(slug)) errors.push(`${slug}: content page is missing from navigation`);
  }
  for (const slug of navSet) {
    if (!docs.has(slug)) errors.push(`${slug}: navigation entry has no content page`);
  }

  for (const [sourceSlug, doc] of docs) {
    for (const link of doc.links) {
      if (
        link.startsWith("http://") ||
        link.startsWith("https://") ||
        link.startsWith("mailto:") ||
        link.startsWith("#")
      ) {
        continue;
      }

      const target = documentTarget(link, sourceSlug);
      if (!target) continue;
      const targetDoc = docs.get(target.slug);
      if (!targetDoc) {
        errors.push(`${sourceSlug}: broken documentation link ${link}`);
      } else if (target.hash && !targetDoc.headings.has(target.hash)) {
        errors.push(`${sourceSlug}: missing heading in documentation link ${link}`);
      }
    }
  }

  return errors.sort();
}

function runCli() {
  const contentRoot = process.env.RASTER_DOCS_CONTENT_ROOT
    ? path.resolve(process.env.RASTER_DOCS_CONTENT_ROOT)
    : path.join(appRoot, "content/docs");
  const navigationFile = process.env.RASTER_DOCS_NAVIGATION_FILE
    ? path.resolve(process.env.RASTER_DOCS_NAVIGATION_FILE)
    : path.join(appRoot, "src/lib/navigation.ts");
  const errors = validateDocs({ contentRoot, navigationFile });

  if (errors.length) {
    console.error(`Documentation validation failed with ${errors.length} error(s):`);
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }

  const pageCount = collectFiles(contentRoot).length;
  console.log(`Documentation validation passed for ${pageCount} pages.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli();
}
