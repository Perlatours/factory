import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { PHASES, computeNextStep, type NextStepInput } from "@/lib/process";
import { Terminal, Eye, Flag, Clock, Ban, CheckCircle2, Compass, ChevronRight, FolderInput } from "lucide-react";

const TONE = {
  go: { ring: "border-cyan-500/40 bg-cyan-500/[0.06]", chip: "bg-cyan-500/15 text-cyan-300 border-cyan-500/30", icon: "text-cyan-400" },
  waiting: { ring: "border-amber-500/40 bg-amber-500/[0.06]", chip: "bg-amber-500/15 text-amber-300 border-amber-500/30", icon: "text-amber-400" },
  done: { ring: "border-blue-500/40 bg-blue-500/[0.06]", chip: "bg-blue-500/15 text-blue-300 border-blue-500/30", icon: "text-blue-400" },
  stop: { ring: "border-red-500/40 bg-red-500/[0.06]", chip: "bg-red-500/15 text-red-300 border-red-500/30", icon: "text-red-400" },
} as const;

/**
 * Guía del proceso: convierte el estado de una conexión en (a) la próxima acción
 * concreta para el developer y (b) el estado en lenguaje llano para quien espera.
 * Server component, solo lectura.
 */
export function ProcessGuide(props: NextStepInput) {
  const step = computeNextStep(props);
  const tone = TONE[step.tone];
  const current = step.phase.n;

  return (
    <Card className={cn("overflow-hidden border", tone.ring)}>
      {/* encabezado */}
      <div className="flex items-center gap-2 border-b border-zinc-800/80 px-5 py-3">
        <Compass className={cn("h-4 w-4", tone.icon)} />
        <span className="text-sm font-semibold tracking-tight">Guía del proceso</span>
        <span className="ml-auto rounded-md border border-zinc-700 bg-zinc-900/60 px-2 py-0.5 text-xs text-zinc-400">
          Fase {current} de 8 · {step.phase.label}
        </span>
      </div>

      {/* stepper de fases 0-8 */}
      <div className="overflow-x-auto px-5 pt-4">
        <ol className="flex min-w-max items-center gap-1">
          {PHASES.map((p, i) => {
            const state = p.n < current ? "done" : p.n === current ? "current" : "todo";
            const plantEdge = p.n === 6; // frontera planta → producto
            return (
              <li key={p.n} className="flex items-center gap-1">
                {plantEdge && (
                  <span className="mx-1 hidden text-[10px] uppercase tracking-wider text-zinc-600 sm:inline">
                    │ producto
                  </span>
                )}
                <div className="flex flex-col items-center gap-1" title={p.short}>
                  <div
                    className={cn(
                      "grid h-7 w-7 place-items-center rounded-full border text-xs font-semibold transition-colors",
                      state === "done" && "border-emerald-500/40 bg-emerald-500/15 text-emerald-300",
                      state === "current" && "border-cyan-400 bg-cyan-500/20 text-cyan-200 ring-2 ring-cyan-500/30",
                      state === "todo" && "border-zinc-700 bg-zinc-900 text-zinc-600"
                    )}
                  >
                    {state === "done" ? <CheckCircle2 className="h-4 w-4" /> : p.n}
                  </div>
                  <span
                    className={cn(
                      "max-w-[64px] text-center text-[10px] leading-tight",
                      state === "current" ? "text-zinc-200" : "text-zinc-500"
                    )}
                  >
                    {p.label}
                  </span>
                </div>
                {i < PHASES.length - 1 && (
                  <ChevronRight className={cn("h-3 w-3 shrink-0", p.n < current ? "text-emerald-600" : "text-zinc-700")} />
                )}
              </li>
            );
          })}
        </ol>
      </div>

      {/* dos lecturas: developer + quien espera */}
      <div className="grid gap-px bg-zinc-800/60 sm:grid-cols-2 mt-4">
        {/* developer */}
        <div className="bg-zinc-950/40 p-5">
          <div className="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wider text-zinc-500">
            <Terminal className="h-3.5 w-3.5" /> Siguiente acción · developer
          </div>
          <div className="flex items-center gap-2">
            {step.tone === "waiting" && <Clock className="h-4 w-4 shrink-0 text-amber-400" />}
            {step.tone === "stop" && <Ban className="h-4 w-4 shrink-0 text-red-400" />}
            <p className="text-sm font-semibold text-zinc-100">{step.devTitle}</p>
          </div>
          {step.devDetail && <p className="mt-1.5 text-xs leading-relaxed text-zinc-400">{step.devDetail}</p>}

          {step.prep && (
            <div className="mt-3 rounded-lg border border-zinc-800 bg-zinc-900/40 p-3">
              <div className="flex items-center gap-1.5 text-[11px] font-semibold text-zinc-300">
                <span className="grid h-4 w-4 place-items-center rounded-full bg-zinc-700 text-[9px] text-zinc-100">1</span>
                <FolderInput className="h-3.5 w-3.5 text-amber-400" /> Prepara
              </div>
              <p className="mt-1.5 text-xs leading-relaxed text-zinc-400">{step.prep.label}</p>
              <code className="mt-1.5 block w-fit rounded-md border border-amber-500/30 bg-amber-500/10 px-2 py-1 font-mono text-[11px] text-amber-200">
                {step.prep.path}
              </code>
            </div>
          )}

          {step.devCommands.length > 0 ? (
            <div className="mt-3">
              <div className="mb-1.5 flex items-center gap-1.5 text-[11px] font-semibold text-zinc-300">
                {step.prep && (
                  <span className="grid h-4 w-4 place-items-center rounded-full bg-zinc-700 text-[9px] text-zinc-100">2</span>
                )}
                <Terminal className="h-3.5 w-3.5 text-cyan-400" /> Ejecuta en Claude Code
                <span className="font-normal text-zinc-500">· terminal</span>
              </div>
              <pre className="overflow-x-auto rounded-lg border border-zinc-800 bg-black/50 p-3 text-[12px] leading-relaxed text-cyan-200/90">
                {step.devCommands.join("\n")}
              </pre>
            </div>
          ) : (
            <p className="mt-3 text-xs italic text-zinc-600">Sin comando — etapa fuera de la planta (repo PerlaHub).</p>
          )}

          <p className="mt-3 border-t border-zinc-800/60 pt-2 text-[10px] leading-relaxed text-zinc-600">
            Todo se controla desde Claude Code en la terminal. El panel solo te dice qué escribir — la skill
            hace el trabajo (lee la doc, marca filas, corre tests) y el panel se actualiza solo.
          </p>
        </div>

        {/* quien espera */}
        <div className="bg-zinc-950/40 p-5">
          <div className="mb-2 flex items-center gap-2 text-xs font-medium uppercase tracking-wider text-zinc-500">
            <Eye className="h-3.5 w-3.5" /> Para quien espera
          </div>
          <p className="text-sm leading-relaxed text-zinc-200">{step.watcherStatus}</p>
          <div className="mt-3 flex items-start gap-2 text-xs text-zinc-400">
            <Flag className="mt-0.5 h-3.5 w-3.5 shrink-0 text-zinc-500" />
            <span>
              <span className="text-zinc-500">Próximo hito: </span>
              {step.watcherMilestone}
            </span>
          </div>
          {step.blockedOn && (
            <div className={cn("mt-3 inline-flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs", tone.chip)}>
              <Clock className="h-3 w-3" /> Esperando: {step.blockedOn}
            </div>
          )}
        </div>
      </div>
    </Card>
  );
}
