import { cn } from "@/lib/utils";

export function Badge({
  children,
  tone = "default",
}: {
  children: React.ReactNode;
  tone?: "default" | "orange" | "green" | "purple" | "amber";
}) {
  const tones = {
    default: "border-border bg-tint text-foreground",
    orange: "border-accent/30 bg-accent-soft text-accent-text",
    green: "border-emerald-600/25 bg-emerald-500/10 text-emerald-800 dark:text-emerald-200",
    purple: "border-process/25 bg-process/10 text-process dark:text-indigo-200",
    amber: "border-amber-600/25 bg-amber-500/10 text-amber-800 dark:text-amber-200",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-normal leading-5",
        tones[tone],
      )}
    >
      {children}
    </span>
  );
}
