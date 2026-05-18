import * as React from "react";
import { cn } from "@/lib/utils";

export function Badge({
  className,
  variant = "default",
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { variant?: "default" | "outline" }) {
  return (
    <div
      className={cn(
        "inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-medium",
        variant === "outline"
          ? "border-zinc-700 text-zinc-300"
          : "border-transparent bg-zinc-800 text-zinc-100",
        className
      )}
      {...props}
    />
  );
}
