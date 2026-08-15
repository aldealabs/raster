import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

export function ButtonLink({
  href,
  children,
  variant = "primary",
}: {
  href: string;
  children: React.ReactNode;
  variant?: "primary" | "ghost";
}) {
  return (
    <Link
      href={href}
      className={cn(
        "inline-flex h-10 items-center justify-center gap-2 rounded-md px-4 text-sm font-normal transition",
        variant === "primary"
          ? "bg-inverse text-inverse-foreground hover:opacity-80"
          : "text-muted hover:text-foreground",
      )}
    >
      {children}
      {variant === "ghost" ? <ArrowRight className="h-3.5 w-3.5" /> : null}
    </Link>
  );
}
