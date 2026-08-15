import type { SearchRecord, TocHeading } from "@/lib/docs";
import Link from "next/link";
import { RasterMark } from "@/components/brand";
import { DocsSidebar } from "@/components/docs/sidebar";
import { Footer } from "@/components/docs/footer";
import { MobileDocsMenu } from "@/components/docs/mobile-docs-menu";
import { SearchDialog } from "@/components/docs/search-dialog";
import { ThemeToggle } from "@/components/docs/theme-toggle";
import { TableOfContents } from "@/components/docs/toc";

export function DocsChrome({
  currentSlug,
  headings,
  records,
  children,
}: {
  currentSlug: string;
  headings: TocHeading[];
  records: SearchRecord[];
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Link
        href="/"
        className="fixed left-5 top-5 z-40 lg:hidden"
        aria-label="Raster documentation home"
      >
        <RasterMark className="h-7 w-7" />
      </Link>
      <div className="fixed right-4 top-4 z-50 flex items-center gap-2 lg:right-6">
        <SearchDialog records={records} />
        <ThemeToggle />
        <MobileDocsMenu currentSlug={currentSlug} />
      </div>
      <div className="mx-auto grid w-full max-w-[1380px] grid-cols-1 lg:grid-cols-[280px_minmax(0,1fr)] xl:grid-cols-[280px_minmax(0,1fr)_260px] 2xl:grid-cols-[280px_minmax(0,820px)_280px]">
        <DocsSidebar currentSlug={currentSlug} />
        <main id="main-content" className="min-w-0 px-6 pb-12 pt-20 md:px-10 lg:py-12 xl:px-12">
          {children}
        </main>
        <TableOfContents headings={headings} />
      </div>
      <Footer />
    </div>
  );
}
