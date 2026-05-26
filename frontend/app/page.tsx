import Link from "next/link";
import { query } from "@/lib/db";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { STATUS_BADGE, FACTORY_BADGE, cn } from "@/lib/utils";
import { compactNextStep } from "@/lib/process";
import { ArrowRight, User, Layers, Compass, Plus } from "lucide-react";

export const dynamic = "force-dynamic";

type ConnRow = {
  slug: string;
  display_name: string;
  factory: string;
  mode: string | null;
  is_pilot: boolean;
  current_phase: number;
  status: string;
  dev_status: string;
  prod_status: string;
  owner_hitl: string | null;
  hitls_pending: string | null;
  checklist_total: string;
  checklist_pending: string;
};

const PHASES = [
  { n: 0, label: "Intake" },
  { n: 1, label: "Análisis doc" },
  { n: 2, label: "Sandbox" },
  { n: 3, label: "Mock tests" },
  { n: 4, label: "Mismatches" },
  { n: 5, label: "Informe" },
  { n: 6, label: "Codificación" },
  { n: 7, label: "E2E" },
  { n: 8, label: "Go-live" },
];

export default async function Home() {
  const conns = (await query<ConnRow>(`
    SELECT c.slug, c.display_name, c.factory, c.mode, c.is_pilot,
           c.current_phase, c.status, c.dev_status, c.prod_status,
           c.owner_hitl,
           (SELECT string_agg('#'||gate_number::text, ',' ORDER BY gate_number)
            FROM hitl_gates h
            WHERE h.connection_id = c.id AND h.status = 'pending') AS hitls_pending,
           (SELECT COUNT(*) FROM checklist_responses cr WHERE cr.connection_id = c.id) AS checklist_total,
           (SELECT COUNT(*) FROM checklist_responses cr
            WHERE cr.connection_id = c.id AND cr.classification IS NULL) AS checklist_pending
    FROM connections c
    WHERE c.status IN ('active','awaiting_intake','dormant')
    ORDER BY c.current_phase DESC, c.slug;
  `)) as ConnRow[];

  const stats = {
    total: conns.length,
    pull: conns.filter((c) => c.factory === "pull").length,
    active: conns.filter((c) => c.status === "active").length,
    awaiting: conns.filter((c) => c.status === "awaiting_intake").length,
  };

  return (
    <div>
      <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Conexiones totales" value={stats.total} hint="Pull + Push + Espejo + Pushout" />
        <StatCard label="Pull (v0 alcance)" value={stats.pull} hint="Único factory operativo v0" accent="cyan" />
        <StatCard label="Active" value={stats.active} hint="En proceso de fabricación" accent="emerald" />
        <StatCard label="Awaiting Intake" value={stats.awaiting} hint="Falta input externo" accent="amber" />
      </div>

      {/* Cómo arranca una conexión nueva — Fase 0 (la skill crea la carpeta, nadie a mano) */}
      <Card className="mb-6 border-dashed border-zinc-700/80 bg-zinc-900/20">
        <div className="flex flex-col gap-3 p-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex items-start gap-3">
            <div className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-zinc-800 text-cyan-400">
              <Plus className="h-4 w-4" />
            </div>
            <div>
              <div className="text-sm font-semibold">¿Nueva conexión? Empieza por el Intake (Fase 0)</div>
              <div className="mt-0.5 text-xs leading-relaxed text-zinc-400">
                Un comando crea la conexión en la DB <span className="text-zinc-200">y su carpeta</span>{" "}
                <code className="rounded bg-zinc-800 px-1 py-0.5 text-[11px] text-cyan-200">pilots/&lt;slug&gt;/</code>{" "}
                (inputs · evidence · outputs) desde la plantilla. Nadie la crea a mano.
              </div>
            </div>
          </div>
          <pre className="overflow-x-auto rounded-lg border border-zinc-800 bg-black/50 p-3 text-[11px] leading-relaxed text-cyan-200/90 lg:max-w-[52%]">
{`# en Claude Code (terminal):
/factory-new <slug> --type pull \\
  --display "..." --contact "Nombre <email>" \\
  --doc-url ... --sandbox-ok yes --volume "..."`}
          </pre>
        </div>
      </Card>

      <div className="mb-4 flex items-end justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Piso de planta</h1>
          <p className="text-sm text-zinc-400">
            Kanban por fase · cada tarjeta es una conexión en fabricación.
          </p>
        </div>
        <div className="text-xs text-zinc-500">{conns.length} conexiones · vivo desde DB</div>
      </div>

      <div className="-mx-6 overflow-x-auto pb-2">
        <div className="flex gap-3 px-6 min-w-max">
          {PHASES.map((p) => {
            const items = conns.filter((c) => c.current_phase === p.n);
            return (
              <div key={p.n} className="w-72 flex-shrink-0">
                <div className="mb-2 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="grid h-6 w-6 place-items-center rounded-md bg-zinc-800 text-xs font-semibold text-zinc-300">
                      {p.n}
                    </div>
                    <span className="text-sm font-medium text-zinc-300">{p.label}</span>
                  </div>
                  <Badge variant="outline" className="bg-zinc-900/60">{items.length}</Badge>
                </div>
                <div className="space-y-2 min-h-[120px] rounded-lg bg-zinc-900/30 p-2">
                  {items.length === 0 ? (
                    <div className="flex h-[100px] items-center justify-center text-xs text-zinc-600">vacío</div>
                  ) : (
                    items.map((c) => <ConnectionCard key={c.slug} c={c} />)
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  hint,
  accent = "zinc",
}: {
  label: string;
  value: number;
  hint: string;
  accent?: "zinc" | "cyan" | "emerald" | "amber";
}) {
  const accents = {
    zinc: "from-zinc-700 to-zinc-800",
    cyan: "from-cyan-600 to-cyan-800",
    emerald: "from-emerald-600 to-emerald-800",
    amber: "from-amber-600 to-amber-800",
  };
  return (
    <Card className="overflow-hidden">
      <div className={cn("h-1 bg-gradient-to-r", accents[accent])} />
      <div className="p-4">
        <div className="text-xs uppercase tracking-wider text-zinc-500">{label}</div>
        <div className="mt-1 text-3xl font-bold tracking-tight">{value}</div>
        <div className="mt-1 text-xs text-zinc-500">{hint}</div>
      </div>
    </Card>
  );
}

function ConnectionCard({ c }: { c: ConnRow }) {
  const statusInfo = STATUS_BADGE[c.status] ?? STATUS_BADGE.dormant;
  const factoryInfo = FACTORY_BADGE[c.factory] ?? FACTORY_BADGE.pull;
  const nextStep = compactNextStep(c.status, c.current_phase, {
    total: Number(c.checklist_total),
    pending: Number(c.checklist_pending),
  });
  return (
    <Link href={`/connections/${c.slug}`}>
      <Card className="group cursor-pointer p-3 hover:bg-zinc-900/80">
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold">{c.slug}</div>
            <div className="truncate text-xs text-zinc-400">{c.display_name}</div>
          </div>
          <ArrowRight className="h-4 w-4 text-zinc-500 transition-transform group-hover:translate-x-0.5 group-hover:text-zinc-300" />
        </div>

        <div className="mt-2 flex flex-wrap gap-1.5">
          <Badge variant="outline" className={cn("text-[10px]", factoryInfo.classes)}>
            <Layers className="mr-1 h-2.5 w-2.5" />
            {factoryInfo.label}
          </Badge>
          {c.mode && (
            <Badge variant="outline" className="text-[10px]">Modo {c.mode}</Badge>
          )}
          {c.is_pilot && (
            <Badge variant="outline" className="text-[10px] bg-purple-500/15 text-purple-300 border-purple-500/30">
              piloto
            </Badge>
          )}
        </div>

        <div className="mt-2 flex items-center justify-between text-xs">
          <div className={cn("rounded-md border px-1.5 py-0.5", statusInfo.classes)}>{statusInfo.label}</div>
          {c.owner_hitl && (
            <div className="flex items-center gap-1 text-zinc-500">
              <User className="h-3 w-3" />
              {c.owner_hitl}
            </div>
          )}
        </div>

        <div className="mt-2 flex items-center gap-1 rounded-md bg-cyan-500/10 px-2 py-1 text-[10px] text-cyan-300">
          <Compass className="h-3 w-3 shrink-0" />
          <span className="truncate">Siguiente: {nextStep}</span>
        </div>

        {c.hitls_pending && (
          <div className="mt-2 rounded-md bg-amber-500/10 px-2 py-1 text-[10px] text-amber-300">
            HITL pendiente: {c.hitls_pending}
          </div>
        )}
      </Card>
    </Link>
  );
}
