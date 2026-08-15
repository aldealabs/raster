import { AlertTriangle, CheckCircle2, Info, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";

const toneMap = {
  note: {
    icon: Info,
    className: "border-accent/30 bg-accent-soft text-foreground",
  },
  tip: {
    icon: Sparkles,
    className: "border-process/30 bg-process/8 text-foreground",
  },
  warning: {
    icon: AlertTriangle,
    className: "border-amber-600/30 bg-amber-500/8 text-amber-900 dark:text-amber-100",
  },
  success: {
    icon: CheckCircle2,
    className: "border-emerald-600/25 bg-emerald-500/8 text-emerald-900 dark:text-emerald-100",
  },
};

export function Aside({
  title,
  tone = "note",
  children,
}: {
  title?: string;
  tone?: keyof typeof toneMap;
  children: React.ReactNode;
}) {
  const config = toneMap[tone];
  const Icon = config.icon;

  return (
    <aside className={cn("my-6 rounded-lg border p-4 text-sm", config.className)}>
      <div className="flex gap-3">
        <Icon className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <div className="min-w-0">
          {title ? <p className="!mt-0 mb-1 font-display font-medium text-heading">{title}</p> : null}
          <div className="aside-content text-muted">{children}</div>
        </div>
      </div>
    </aside>
  );
}
