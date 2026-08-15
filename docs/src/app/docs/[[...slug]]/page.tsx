import Link from "next/link";
import { notFound } from "next/navigation";
import { compileMDX } from "next-mdx-remote/rsc";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypePrettyCode from "rehype-pretty-code";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";
import { ArrowLeft, ArrowRight } from "lucide-react";
import { DocsChrome } from "@/components/docs/site-chrome";
import { mdxComponents } from "@/components/docs/mdx-components";
import { codeHighlightOptions } from "@/lib/code-highlighting";
import { getAdjacentDocs, getAllDocs, getDoc, getSearchIndex } from "@/lib/docs";
import { getDocPath } from "@/lib/navigation";

type PageProps = {
  params: Promise<{ slug?: string[] }>;
};

export function generateStaticParams() {
  return [
    { slug: [] },
    ...getAllDocs().map((doc) => ({ slug: doc.slug.split("/") })),
  ];
}

export const dynamicParams = false;

export async function generateMetadata({ params }: PageProps) {
  const resolved = await params;
  const slug = resolved.slug?.join("/");
  if (!slug) {
    return {
      title: "Introduction",
      description: "Learn how Raster turns image recipes into Metal work.",
    };
  }
  const doc = getDoc(slug);
  if (!doc) return {};
  return {
    title: doc.title,
    description: doc.description,
  };
}

export default async function DocsPage({ params }: PageProps) {
  const resolved = await params;
  const slug = resolved.slug?.join("/") || "start/overview";
  const doc = getDoc(slug);
  if (!doc) notFound();

  const { content } = await compileMDX({
    source: doc.content,
    components: mdxComponents,
    options: {
      mdxOptions: {
        remarkPlugins: [remarkGfm],
        rehypePlugins: [
          rehypeSlug,
          [rehypePrettyCode, codeHighlightOptions],
          [rehypeAutolinkHeadings, { behavior: "wrap" }],
        ],
      },
    },
  });
  const adjacent = getAdjacentDocs(slug);

  return (
    <DocsChrome currentSlug={slug} headings={doc.headings} records={getSearchIndex()}>
      <article className="docs-prose min-w-0 max-w-full">
        <div className="mb-10">
          <p className="eyebrow mb-4">{doc.tabTitle} / {doc.sectionTitle}</p>
          <h1>{doc.title}</h1>
          <p className="lead">{doc.description}</p>
        </div>
        {content}
      </article>
      <nav className="mt-16 grid min-w-0 grid-cols-2 gap-5 border-t border-border pt-8 text-sm font-normal">
        {adjacent.previous ? (
          <Link
            href={getDocPath(adjacent.previous.slug)}
            className="flex items-center gap-2 text-muted hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            {adjacent.previous.title}
          </Link>
        ) : <span />}
        {adjacent.next ? (
          <Link
            href={getDocPath(adjacent.next.slug)}
            className="ml-auto flex items-center gap-2 text-right text-muted hover:text-foreground"
          >
            {adjacent.next.title}
            <ArrowRight className="h-4 w-4" />
          </Link>
        ) : null}
      </nav>
    </DocsChrome>
  );
}
