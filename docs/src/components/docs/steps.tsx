export function Steps({ children }: { children: React.ReactNode }) {
  return <ol className="steps my-7 [counter-reset:step]">{children}</ol>;
}

export function Step({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <li className="relative py-2 pl-14 [counter-increment:step]" aria-label={`Step ${title}`}>
      <span className="absolute left-0 top-2 flex h-7 w-7 items-center justify-center rounded-full border border-accent/40 bg-accent-soft text-xs font-normal text-accent-text before:content-[counter(step)]" />
      <div className="text-muted">{children}</div>
    </li>
  );
}
