import fs from "node:fs";
import path from "node:path";
import matter from "gray-matter";
import { getFlatNavItems } from "@/lib/navigation";

const docsRoot = path.join(process.cwd(), "content/docs");

export type DocFrontmatter = {
  title: string;
  description: string;
  section?: string;
  status?: string;
};

export type DocRecord = {
  slug: string;
  href: string;
  title: string;
  description: string;
  sectionTitle: string;
  tabTitle: string;
  content: string;
  frontmatter: DocFrontmatter;
  headings: TocHeading[];
  rawText: string;
};

export type TocHeading = {
  id: string;
  title: string;
  depth: number;
};

export type SearchRecord = {
  slug: string;
  href: string;
  title: string;
  description: string;
  sectionTitle: string;
  tabTitle: string;
  text: string;
  headings: TocHeading[];
};

function slugToFilePath(slug: string) {
  return path.join(docsRoot, `${slug}.mdx`);
}

function slugifyHeading(value: string) {
  return value
    .toLowerCase()
    .replace(/`([^`]+)`/g, "$1")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");
}

function stripMdx(value: string) {
  return value
    .replace(/^---[\s\S]*?---/m, "")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/[{}[\]()*_#>`~|]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function extractHeadings(source: string): TocHeading[] {
  const headings: TocHeading[] = [];
  for (const match of source.matchAll(/^(##|###)\s+(.+)$/gm)) {
    const title = match[2].replace(/\s+\{#.*?\}\s*$/, "").trim();
    headings.push({
      id: slugifyHeading(title),
      title: title.replace(/`/g, ""),
      depth: match[1].length,
    });
  }
  return headings;
}

export function getDoc(slug: string): DocRecord | null {
  const filePath = slugToFilePath(slug);
  if (!fs.existsSync(filePath)) return null;

  const nav = getFlatNavItems().find((item) => item.slug === slug);
  const raw = fs.readFileSync(filePath, "utf8");
  const parsed = matter(raw);
  const frontmatter = parsed.data as DocFrontmatter;
  const title = frontmatter.title ?? nav?.title ?? slug;
  const description = frontmatter.description ?? nav?.sectionTitle ?? "";

  return {
    slug,
    href: `/docs/${slug}`,
    title,
    description,
    sectionTitle: nav?.sectionTitle ?? frontmatter.section ?? "Documentation",
    tabTitle: nav?.tabTitle ?? "Documentation",
    content: parsed.content,
    frontmatter,
    headings: extractHeadings(parsed.content),
    rawText: stripMdx(parsed.content),
  };
}

export function getAllDocs(): DocRecord[] {
  return getFlatNavItems()
    .map((item) => getDoc(item.slug))
    .filter((doc): doc is DocRecord => Boolean(doc));
}

export function getSearchIndex(): SearchRecord[] {
  return getAllDocs().map((doc) => ({
    slug: doc.slug,
    href: doc.href,
    title: doc.title,
    description: doc.description,
    sectionTitle: doc.sectionTitle,
    tabTitle: doc.tabTitle,
    text: `${doc.title} ${doc.description} ${doc.sectionTitle} ${doc.tabTitle} ${doc.rawText}`,
    headings: doc.headings,
  }));
}

export function getAdjacentDocs(slug: string) {
  const docs = getFlatNavItems();
  const index = docs.findIndex((item) => item.slug === slug);
  return {
    previous: index > 0 ? docs[index - 1] : null,
    next: index >= 0 && index < docs.length - 1 ? docs[index + 1] : null,
  };
}

