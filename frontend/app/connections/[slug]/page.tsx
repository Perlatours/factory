import Link from "next/link";
import { notFound } from "next/navigation";
import { query } from "@/lib/db";
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { STATUS_BADGE, FACTORY_BADGE, CLASSIFICATION_DOT, cn } from "@/lib/utils";
import { ArrowLeft, Mail, Calendar, AlertTriangle, CheckCircle2, CircleDot, Activity } from "lucide-react";

export const dynamic = "force-dynamic";

type Connection = {
  id: number;
  slug: string;
  display_name: string;
  factory: string;
  mode: string | null;
  is_pilot: boolean;
  current_phase: number;
  status: string;
  dev_status: string;
  prod_status: string;
  dev_commit: string | null;
  prod_commit: string | null;
  dev_pr_url: string | null;
  prod_pr_url: string | null;
  owner_hitl: string | null;
  contact_name: string | null;
  contact_email: string | null;
  intake_doc_url: string | null;
  intake_volume_notes: string | null;
  notes: string | null;
  updated_at: string;
  created_at: string;
};

type HITL = {
  gate_number: number;
  gate_title: string;
  status: string;
  approver: string | null;
  decided_at: string | null;
  notes: string | null;
};

type PhaseLog = {
  from_phase: number | null;
  to_phase: number;
  actor: string;
  occurred_at: string;
  notes: string | null;
};

type ChecklistSection = {
  section: string;
  total: string;
  pending: string;
  green: string;
  yellow: string;
  red: string;
  na: string;
};

type Surprise = {
  id: number;
  title: string;
  description: string | null;
  catalog_anexo: string | null;
  resolved: boolean;
  detected_at: string;
};

type Action = {
  phase: number;
  action_type: string;
  target_env: string;
  outcome: string | null;
  notes: string | null;
  occurred_at: string;
};

export default async function ConnectionDetail({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  const [connection] = (await query<Connection>(
    `SELECT * FROM connections WHERE slug = $1`,
    [slug]
  )) as Connection[];

  if (!connection) notFound();

  const hitls = (await query<HITL>(
    `SELECT gate_number, gate_title, status, approver, decided_at, notes
     FROM hitl_gates WHERE connection_id = $1 ORDER BY gate_number`,
    [connection.id]
  )) as HITL[];

  const phaseLog = (await query<PhaseLog>(
    `SELECT from_phase, to_phase, actor, occurred_at, notes
     FROM phase_log WHERE connection_id = $1 ORDER BY occurred_at DESC LIMIT 20`,
    [connection.id]
  )) as PhaseLog[];

  const checklist = (await query<ChecklistSection>(
    `SELECT section,
            COUNT(*)::text AS total,
            COUNT(*) FILTER (WHERE classification IS NULL)::text AS pending,
            COUNT(*) FILTER (WHERE classification='green')::text  AS green,
            COUNT(*) FILTER (WHERE classification='yellow')::text AS yellow,
            COUNT(*) FILTER (WHERE classification='red')::text    AS red,
            COUNT(*) FILTER (WHERE classification='na')::text     AS na
     FROM checklist_responses WHERE connection_id = $1
     GROUP BY section ORDER BY section`,
    [connection.id]
  )) as ChecklistSection[];

  const surprises = (await query<Surprise>(
    `SELECT id, title, description, catalog_anexo, resolved, detected_at
     FROM surprises WHERE connection_id = $1
     ORDER BY resolved, detected_at DESC`,
    [connection.id]
  )) as Surprise[];

  const actions = (await query<Action>(
    `SELECT phase, action_type, target_env, outcome, notes, occurred_at
     FROM actions WHERE connection_id = $1
     ORDER BY occurred_at DESC LIMIT 30`,
    [connection.id]
  )) as Action[];

  const statusInfo = STATUS_BADGE[connection.status] ?? STATUS_BADGE.dormant;
  const factoryInfo = FACTORY_BADGE[connection.factory] ?? FACTORY_BADGE.pull;

  return (
    <div className="space-y-6">
      <Link
        href="/"
        className="inline-flex items-center gap-2 text-sm text-zinc-400 hover:text-zinc-100"
      >
        <ArrowLeft className="h-4 w-4" /> Volver al piso de planta
      </Link>

      {/* Header card */}
      <Card>
        <div className="border-b border-zinc-800 p-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <Badge variant="outline" className={factoryInfo.classes}>{factoryInfo.label}</Badge>
                {connection.mode && <Badge variant="outline">Modo {connection.mode}</Badge>}
                {connection.is_pilot && (
                  <Badge variant="outline" className="bg-purple-500/15 text-purple-300 border-purple-500/30">
                    Piloto
                  </Badge>
                )}
              </div>
              <h1 className="text-2xl font-bold tracking-tight">{connection.slug}</h1>
              <p className="text-zinc-400 mt-1">{connection.display_name}</p>
            </div>
            <div className={cn("rounded-md border px-3 py-1.5 text-sm font-medium", statusInfo.classes)}>
              {statusInfo.label}
            </div>
          </div>
        </div>

        <div className="grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-4">
          <Metric label="Fase actual" value={`${connection.current_phase} / 8`} />
          <Metric label="DEV" value={connection.dev_status} />
          <Metric label="PROD" value={connection.prod_status} />
          <Metric label="Owner HITL" value={connection.owner_hitl ?? "—"} />
        </div>

        {(connection.contact_name || connection.notes || connection.intake_volume_notes) && (
          <div className="border-t border-zinc-800 p-5 space-y-2">
            {connection.contact_name && (
              <div className="flex items-center gap-2 text-sm text-zinc-300">
                <Mail className="h-4 w-4 text-zinc-500" />
                <span className="font-medium">{connection.contact_name}</span>
                {connection.contact_email && <span className="text-zinc-500">· {connection.contact_email}</span>}
              </div>
            )}
            {connection.intake_volume_notes && (
              <div className="text-sm text-zinc-400">
                <span className="text-zinc-500">Volumen: </span>
                {connection.intake_volume_notes}
              </div>
            )}
            {connection.notes && (
              <div className="rounded-md bg-zinc-900/60 p-3 text-sm text-zinc-300">
                {connection.notes}
              </div>
            )}
          </div>
        )}
      </Card>

      {/* HITL Gates */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-emerald-400" /> HITL Gates
          </CardTitle>
          <CardDescription>Puntos de control de calidad humano</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-2">
            {hitls.map((h) => (
              <div
                key={h.gate_number}
                className={cn(
                  "rounded-lg border p-3",
                  h.status === "approved"
                    ? "border-emerald-500/30 bg-emerald-500/5"
                    : h.status === "rejected"
                      ? "border-red-500/30 bg-red-500/5"
                      : "border-amber-500/30 bg-amber-500/5"
                )}
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <div className="grid h-7 w-7 place-items-center rounded-md bg-zinc-900 text-xs font-bold">
                      #{h.gate_number}
                    </div>
                    <div>
                      <div className="font-medium text-sm">{h.gate_title}</div>
                      {h.notes && <div className="text-xs text-zinc-500 mt-0.5">{h.notes}</div>}
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge
                      variant="outline"
                      className={cn(
                        "text-xs",
                        h.status === "approved" && "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
                        h.status === "rejected" && "bg-red-500/15 text-red-300 border-red-500/30",
                        h.status === "pending" && "bg-amber-500/15 text-amber-300 border-amber-500/30"
                      )}
                    >
                      {h.status}
                    </Badge>
                    {h.approver && (
                      <div className="text-xs text-zinc-500 mt-1">
                        {h.approver} · {h.decided_at ? new Date(h.decided_at).toLocaleDateString("es-ES") : ""}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Checklist progress */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CircleDot className="h-5 w-5 text-cyan-400" /> Checklist técnica
            </CardTitle>
            <CardDescription>15 secciones · marcado 🟢🟡🔴 por fila</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            {checklist.length === 0 ? (
              <div className="text-sm text-zinc-500">
                Sin filas de checklist (¿Push / rejected_intake?)
              </div>
            ) : (
              checklist.map((s) => {
                const total = Number(s.total);
                const green = Number(s.green);
                const yellow = Number(s.yellow);
                const red = Number(s.red);
                const na = Number(s.na);
                const pending = Number(s.pending);
                return (
                  <div key={s.section} className="space-y-1">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-medium text-zinc-300">Sección {s.section}</span>
                      <span className="text-zinc-500">
                        {total - pending}/{total}
                      </span>
                    </div>
                    <div className="flex h-2 overflow-hidden rounded-full bg-zinc-800">
                      {green > 0 && <div className={cn(CLASSIFICATION_DOT.green)} style={{ width: `${(green / total) * 100}%` }} />}
                      {yellow > 0 && <div className={cn(CLASSIFICATION_DOT.yellow)} style={{ width: `${(yellow / total) * 100}%` }} />}
                      {red > 0 && <div className={cn(CLASSIFICATION_DOT.red)} style={{ width: `${(red / total) * 100}%` }} />}
                      {na > 0 && <div className={cn(CLASSIFICATION_DOT.na)} style={{ width: `${(na / total) * 100}%` }} />}
                    </div>
                    <div className="flex gap-3 text-[11px] text-zinc-500">
                      {green > 0 && <span className="text-emerald-400">{green} 🟢</span>}
                      {yellow > 0 && <span className="text-amber-400">{yellow} 🟡</span>}
                      {red > 0 && <span className="text-red-400">{red} 🔴</span>}
                      {na > 0 && <span>{na} n/a</span>}
                      {pending > 0 && <span>{pending} pending</span>}
                    </div>
                  </div>
                );
              })
            )}
          </CardContent>
        </Card>

        {/* Sorpresas */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-amber-400" /> Sorpresas
            </CardTitle>
            <CardDescription>Hallazgos no anticipados (insumo Anexo D)</CardDescription>
          </CardHeader>
          <CardContent>
            {surprises.length === 0 ? (
              <div className="text-sm text-zinc-500">Sin sorpresas registradas.</div>
            ) : (
              <div className="space-y-2">
                {surprises.map((s) => (
                  <div
                    key={s.id}
                    className={cn(
                      "rounded-md border p-3 text-sm",
                      s.resolved ? "border-emerald-500/20 bg-emerald-500/5" : "border-amber-500/30 bg-amber-500/5"
                    )}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-medium">{s.title}</span>
                      {s.catalog_anexo && (
                        <Badge variant="outline" className="text-[10px]">Anexo {s.catalog_anexo}</Badge>
                      )}
                    </div>
                    {s.description && <div className="text-xs text-zinc-400 mt-1">{s.description}</div>}
                    <div className="text-[10px] text-zinc-600 mt-1">
                      {s.resolved ? "✓ resuelta" : "abierta"} · {new Date(s.detected_at).toLocaleDateString("es-ES")}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Phase log */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="h-5 w-5 text-violet-400" /> Phase log
          </CardTitle>
          <CardDescription>Transiciones de fase, incluido rebobinado (idempotencia)</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {phaseLog.length === 0 ? (
              <div className="text-sm text-zinc-500">Sin transiciones.</div>
            ) : (
              phaseLog.map((p, i) => {
                const isRewind = p.from_phase !== null && p.to_phase < p.from_phase;
                return (
                  <div key={i} className="flex items-start gap-3 text-sm">
                    <div className="grid h-6 w-6 place-items-center rounded-full bg-zinc-900 text-xs text-zinc-400 mt-0.5">
                      {p.to_phase}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-medium">
                          {p.from_phase === null ? "→" : `${p.from_phase} →`} {p.to_phase}
                        </span>
                        {isRewind && (
                          <Badge variant="outline" className="text-[10px] bg-violet-500/15 text-violet-300 border-violet-500/30">
                            rebobinado
                          </Badge>
                        )}
                        <span className="text-xs text-zinc-500">{p.actor}</span>
                      </div>
                      {p.notes && <div className="text-xs text-zinc-400 mt-0.5">{p.notes}</div>}
                      <div className="text-[10px] text-zinc-600 mt-0.5">
                        {new Date(p.occurred_at).toLocaleString("es-ES", { hour12: false })}
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </CardContent>
      </Card>

      {/* Actions */}
      {actions.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-5 w-5 text-cyan-400" /> Actions (audit)
            </CardTitle>
            <CardDescription>Acciones técnicas registradas (sandbox/mock/deploy/...)</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead className="text-zinc-500 border-b border-zinc-800">
                  <tr>
                    <th className="text-left py-2">phase</th>
                    <th className="text-left py-2">action</th>
                    <th className="text-left py-2">env</th>
                    <th className="text-left py-2">outcome</th>
                    <th className="text-left py-2">when</th>
                    <th className="text-left py-2">notes</th>
                  </tr>
                </thead>
                <tbody>
                  {actions.map((a, i) => (
                    <tr key={i} className="border-b border-zinc-900">
                      <td className="py-2">{a.phase}</td>
                      <td className="py-2 font-mono">{a.action_type}</td>
                      <td className="py-2">{a.target_env}</td>
                      <td className="py-2">
                        {a.outcome && (
                          <Badge
                            variant="outline"
                            className={cn(
                              "text-[10px]",
                              a.outcome === "pass" && "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
                              a.outcome === "fail" && "bg-red-500/15 text-red-300 border-red-500/30",
                              a.outcome === "partial" && "bg-amber-500/15 text-amber-300 border-amber-500/30"
                            )}
                          >
                            {a.outcome}
                          </Badge>
                        )}
                      </td>
                      <td className="py-2 text-zinc-500">
                        {new Date(a.occurred_at).toLocaleString("es-ES", { hour12: false })}
                      </td>
                      <td className="py-2 text-zinc-400">{a.notes}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wider text-zinc-500">{label}</div>
      <div className="mt-1 text-base font-medium">{value}</div>
    </div>
  );
}
