import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { RasterLockup } from "@/components/brand";
import { Footer } from "@/components/docs/footer";
import { ThemeToggle } from "@/components/docs/theme-toggle";
import { docsTabs, getDocPath, type DocsTab } from "@/lib/navigation";

const quickStarts = [
  {
    label: "Install",
    detail: "Swift Package Manager setup",
    slug: "start/installation",
  },
  {
    label: "First pipeline",
    detail: "A first load, filter, and render",
    slug: "start/first-pipeline",
  },
  {
    label: "Migrate",
    detail: "From MetalPetal 1.26 to Raster 2.x",
    slug: "start/migrating-from-metalpetal",
  },
] as const;

const consumerTabs = docsTabs.filter((tab) =>
  ["start", "framework", "guides", "reference"].includes(tab.id),
);
const maintainerTabs = docsTabs.filter((tab) =>
  ["internals", "contributing"].includes(tab.id),
);

function DirectoryGroup({ tab, compact = false }: { tab: DocsTab; compact?: boolean }) {
  const items = tab.sections.flatMap((section) => section.items);

  return (
    <section className={`directory-group ${compact ? "directory-group-compact" : ""}`}>
      <div>
        <h3 className="font-display text-xl font-medium tracking-[-0.02em] text-heading">
          {tab.title}
        </h3>
        <p className="mt-1 text-xs leading-5 text-dim">{tab.description}</p>
      </div>
      <ul className={compact ? "grid gap-2.5" : "grid gap-x-7 gap-y-2.5 sm:grid-cols-2"}>
        {items.map((item) => (
          <li key={item.slug}>
            <Link
              href={getDocPath(item.slug)}
              className="group inline-flex items-baseline gap-2 text-sm text-muted transition hover:text-foreground"
            >
              <span>{item.title}</span>
              {item.badge ? (
                <span className="font-tech text-[9px] uppercase tracking-[0.08em] text-accent-text">
                  {item.badge}
                </span>
              ) : null}
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

export default function Home() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-border">
        <div className="mx-auto flex h-16 max-w-[1240px] items-center justify-between px-6 lg:px-10">
          <Link href="/" aria-label="Raster documentation home">
            <RasterLockup className="w-[126px]" />
          </Link>
          <div className="flex items-center gap-4">
            <nav className="flex items-center gap-5 text-sm text-muted" aria-label="Primary">
              <Link href="/docs" className="transition hover:text-foreground">Docs</Link>
              <a href="https://github.com/aldealabs/raster" className="transition hover:text-foreground">
                GitHub
              </a>
            </nav>
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main>
        <section className="border-b border-border">
          <div className="mx-auto max-w-[1240px] px-6 py-12 lg:px-10 lg:py-14">
            <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_380px] lg:items-end lg:gap-16">
              <div>
                <div className="mb-5 flex items-center gap-3">
                  <span className="scan-trace" aria-hidden="true" />
                  <p className="eyebrow">Raster 2.x</p>
                </div>
                <h1 className="font-display text-[clamp(2.55rem,4.2vw,3.8rem)] font-medium leading-[0.98] tracking-[-0.045em] text-heading">
                  Raster documentation
                </h1>
              </div>
              <p className="max-w-xl text-base leading-7 text-muted lg:pb-1">
                Build still-image and video pipelines with Metal. Raster is a continuation of the excellent <a href="https://github.com/MetalPetal/MetalPetal" className="text-accent-text" target="_blank">MetalPetal</a> image processing framework.
              </p>
            </div>
          </div>

          <div className="border-t border-border">
            <nav
              aria-label="Get started"
              className="mx-auto grid max-w-[1240px] border-l border-border md:grid-cols-3"
            >
              {quickStarts.map((item) => (
                <Link key={item.slug} href={getDocPath(item.slug)} className="quick-start group">
                  <div>
                    <span className="font-display text-lg font-medium text-heading">{item.label}</span>
                    <span className="mt-1 block text-xs leading-5 text-dim">{item.detail}</span>
                  </div>
                  <ArrowRight className="h-4 w-4 shrink-0 text-dim transition group-hover:translate-x-1 group-hover:text-foreground" />
                </Link>
              ))}
            </nav>
          </div>
        </section>

        <section className="mx-auto grid max-w-[1240px] gap-12 px-6 py-12 lg:grid-cols-[minmax(0,1fr)_320px] lg:gap-16 lg:px-10 lg:py-14">
          <div>
            <p className="eyebrow mb-5">Use Raster</p>
            <div className="border-b border-border">
              {consumerTabs.map((tab) => <DirectoryGroup key={tab.id} tab={tab} />)}
            </div>
          </div>

          <aside className="lg:border-l lg:border-border lg:pl-10">
            <p className="eyebrow mb-5">Maintain Raster</p>
            <div className="border-b border-border">
              {maintainerTabs.map((tab) => <DirectoryGroup key={tab.id} tab={tab} compact />)}
            </div>

            <div className="mt-8 border-l-2 border-accent pl-4">
              <p className="font-tech text-[10px] uppercase tracking-[0.13em] text-dim">
                MetalPetal continuation
              </p>
              <p className="mt-2 text-sm leading-6 text-muted">
                Raster continues MetalPetal with the same image model and <code className="font-mono text-[0.88em]">MTI*</code> type names.
              </p>
              <Link
                href={getDocPath("start/migrating-from-metalpetal")}
                className="mt-3 inline-flex items-center gap-2 text-sm text-foreground"
              >
                Migration guide <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            </div>
          </aside>
        </section>
      </main>

      <Footer />
    </div>
  );
}
