"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

/**
 * Refresca los server components cada `seconds` sin recargar la página (App Router).
 * Botón en el header para pausar/reanudar; punto verde = en vivo.
 */
export function AutoRefresh({ seconds = 15 }: { seconds?: number }) {
  const router = useRouter();
  const [on, setOn] = useState(true);

  useEffect(() => {
    if (!on) return;
    const id = setInterval(() => router.refresh(), seconds * 1000);
    return () => clearInterval(id);
  }, [router, seconds, on]);

  return (
    <button
      type="button"
      onClick={() => setOn((v) => !v)}
      title={on ? `Auto-refresca cada ${seconds}s — clic para pausar` : "Pausado — clic para reanudar"}
      className="flex items-center gap-1.5 rounded-md border border-zinc-800 bg-zinc-900/60 px-2 py-1 text-[11px] text-zinc-400 hover:text-zinc-200"
    >
      <span
        className={
          on
            ? "h-2 w-2 rounded-full bg-emerald-400 animate-pulse"
            : "h-2 w-2 rounded-full bg-zinc-600"
        }
      />
      {on ? "en vivo" : "pausado"}
    </button>
  );
}
