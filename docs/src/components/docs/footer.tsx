export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-border bg-surface">
      <div className="mx-auto flex max-w-[1380px] flex-col items-center justify-between gap-4 px-7 py-7 sm:flex-row">
        <p className="text-center text-xs font-normal text-muted">Raster · © Aldea Labs, {year}</p>
        <div className="flex gap-5 text-xs text-dim">
          <a href="https://github.com/aldealabs/raster" className="hover:text-foreground">GitHub</a>
          <a href="https://github.com/aldealabs/raster/blob/HEAD/LICENSE" className="hover:text-foreground">MIT License</a>
        </div>
      </div>
    </footer>
  );
}
