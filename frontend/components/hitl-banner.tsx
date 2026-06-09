import { connection } from "next/server";
import { query } from "@/lib/db";
import { AlertTriangle, CheckCircle2, Clock } from "lucide-react";

type HITLRow = {
  slug: string;
  factory: string;
  gate_number: number;
  gate_title: string;
  owner: string;
  days_waiting: number;
};

export async function HITLBanner() {
  // El banner vive en el root layout (envuelve también /_not-found). Sin esto,
  // Next intenta prerenderizarlo en build time y la query a la DB falla (ECONNREFUSED).
  // connection() difiere el render a request time, cuando factory-db sí es alcanzable.
  await connection();
  const rows = (await query<HITLRow>(`
    SELECT c.slug, c.factory, h.gate_number, h.gate_title,
           COALESCE(c.owner_hitl, '—') AS owner,
           EXTRACT(EPOCH FROM (NOW() - c.updated_at)) / 86400.0 AS days_waiting
    FROM hitl_gates h
    JOIN connections c ON c.id = h.connection_id
    WHERE h.status = 'pending'
      AND c.status IN ('active','awaiting_intake')
    ORDER BY c.updated_at;
  `)) as HITLRow[];

  if (rows.length === 0) {
    return (
      <div className="mb-6 flex items-center gap-3 rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-3">
        <CheckCircle2 className="h-5 w-5 text-emerald-400" />
        <div className="text-sm text-emerald-100">
          <span className="font-semibold">Sin HITL gates pendientes.</span>{" "}
          <span className="text-emerald-300/80">La planta no está bloqueada esperando revisión humana.</span>
        </div>
      </div>
    );
  }

  const overdue = rows.filter((r) => Number(r.days_waiting) > 2);
  const critical = overdue.length > 0;

  return (
    <div
      className={`mb-6 rounded-xl border px-4 py-3 ${
        critical
          ? "border-red-500/40 bg-red-500/10"
          : "border-amber-500/40 bg-amber-500/10"
      }`}
    >
      <div className="flex items-center gap-3">
        <AlertTriangle className={critical ? "h-5 w-5 text-red-400" : "h-5 w-5 text-amber-400"} />
        <div className="flex-1 text-sm">
          <span className="font-semibold">
            {rows.length} HITL gate{rows.length > 1 ? "s" : ""} pendiente
            {rows.length > 1 ? "s" : ""}
          </span>
          <span className={critical ? "text-red-300/80 ml-2" : "text-amber-300/80 ml-2"}>
            ({overdue.length} {">"}2 días esperando)
          </span>
        </div>
      </div>
      <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
        {rows.slice(0, 6).map((r) => (
          <div
            key={`${r.slug}-${r.gate_number}`}
            className="flex items-center justify-between rounded-md bg-zinc-950/40 px-3 py-2 text-xs"
          >
            <div className="min-w-0">
              <div className="font-medium text-zinc-100 truncate">{r.slug}</div>
              <div className="text-zinc-400 truncate">
                #{r.gate_number} · {r.gate_title}
              </div>
            </div>
            <div className="flex items-center gap-1 text-zinc-400">
              <Clock className="h-3 w-3" />
              {Number(r.days_waiting).toFixed(1)}d
            </div>
          </div>
        ))}
        {rows.length > 6 && (
          <div className="rounded-md bg-zinc-950/40 px-3 py-2 text-xs text-zinc-400">
            + {rows.length - 6} más…
          </div>
        )}
      </div>
    </div>
  );
}
