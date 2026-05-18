import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const STATUS_BADGE: Record<string, { label: string; classes: string }> = {
  active: { label: "🟢 Active", classes: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30" },
  awaiting_intake: { label: "🟡 Awaiting Intake", classes: "bg-amber-500/15 text-amber-300 border-amber-500/30" },
  dormant: { label: "💤 Dormant", classes: "bg-slate-500/15 text-slate-300 border-slate-500/30" },
  done: { label: "✅ Done", classes: "bg-blue-500/15 text-blue-300 border-blue-500/30" },
  rejected_intake: { label: "🚫 Rejected", classes: "bg-red-500/15 text-red-300 border-red-500/30" },
  dropped: { label: "Dropped", classes: "bg-zinc-500/15 text-zinc-300 border-zinc-500/30" },
};

export const FACTORY_BADGE: Record<string, { label: string; classes: string }> = {
  pull: { label: "Pull", classes: "bg-cyan-500/15 text-cyan-300 border-cyan-500/30" },
  push: { label: "Push", classes: "bg-fuchsia-500/15 text-fuchsia-300 border-fuchsia-500/30" },
  espejo: { label: "Espejo", classes: "bg-violet-500/15 text-violet-300 border-violet-500/30" },
  pushout: { label: "PushOut", classes: "bg-orange-500/15 text-orange-300 border-orange-500/30" },
};

export const CLASSIFICATION_DOT: Record<string, string> = {
  green: "bg-emerald-500",
  yellow: "bg-amber-500",
  red: "bg-red-500",
  na: "bg-zinc-500",
};
