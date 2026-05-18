import { query } from "@/lib/db";
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { TrendingUp, Lightbulb, BookOpen } from "lucide-react";

export const dynamic = "force-dynamic";

type TopRed = {
  row_key: string;
  row_label: string;
  total_marked: string;
  reds: string;
  yellows: string;
  greens: string;
  pct_red: string | null;
};

type ResolvedSurprise = {
  title: string;
  catalog_anexo: string | null;
  slug: string;
  resolution_notes: string | null;
  resolved_at: string;
};

type Counts = {
  total_conns: string;
  done_conns: string;
  active_conns: string;
  marked_rows: string;
  total_surprises: string;
};

export default async function Learning() {
  const topReds = (await query<TopRed>(`
    SELECT row_key, row_label,
           COUNT(*)::text AS total_marked,
           COUNT(*) FILTER (WHERE classification='red')::text AS reds,
           COUNT(*) FILTER (WHERE classification='yellow')::text AS yellows,
           COUNT(*) FILTER (WHERE classification='green')::text AS greens,
           ROUND(100.0 * COUNT(*) FILTER (WHERE classification='red') / NULLIF(COUNT(*),0), 1)::text AS pct_red
    FROM checklist_responses
    WHERE classification IS NOT NULL
    GROUP BY row_key, row_label
    HAVING COUNT(*) >= 1
    ORDER BY pct_red DESC NULLS LAST, total_marked DESC
    LIMIT 30;
  `)) as TopRed[];

  const resolved = (await query<ResolvedSurprise>(`
    SELECT s.title, s.catalog_anexo, c.slug, s.resolution_notes, s.resolved_at
    FROM surprises s JOIN connections c ON c.id = s.connection_id
    WHERE s.resolved
    ORDER BY s.resolved_at DESC LIMIT 30;
  `)) as ResolvedSurprise[];

  const [counts] = (await query<Counts>(`
    SELECT
      (SELECT COUNT(*) FROM connections)::text AS total_conns,
      (SELECT COUNT(*) FROM connections WHERE status='done')::text AS done_conns,
      (SELECT COUNT(*) FROM connections WHERE status='active')::text AS active_conns,
      (SELECT COUNT(*) FROM checklist_responses WHERE classification IS NOT NULL)::text AS marked_rows,
      (SELECT COUNT(*) FROM surprises)::text AS total_surprises;
  `)) as Counts[];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Aprendizaje cross-conexión</h1>
        <p className="text-sm text-zinc-400">
          Patterns que emergen al fabricar varias conexiones · candidatos a wrapper Core
        </p>
      </div>

      {/* Counts row */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <Count label="Conexiones totales" value={counts.total_conns} />
        <Count label="Active" value={counts.active_conns} />
        <Count label="Done" value={counts.done_conns} />
        <Count label="Filas checklist marcadas" value={counts.marked_rows} />
        <Count label="Sorpresas registradas" value={counts.total_surprises} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TrendingUp className="h-5 w-5 text-red-400" /> Top filas problemáticas
          </CardTitle>
          <CardDescription>
            Filas con mayor % 🔴 cross-conexión — candidatas a wrapper Core en PerlaHub.
            Esta pantalla crece tras los primeros cierres reales.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {topReds.length === 0 ? (
            <div className="rounded-md bg-zinc-900/40 p-6 text-center text-sm text-zinc-500">
              <Lightbulb className="h-8 w-8 text-zinc-600 mx-auto mb-2" />
              Aún no hay datos cross-conexión.
              <div className="text-xs mt-1">Empieza a clasificar filas con <code className="bg-zinc-800 px-1 rounded">/factory-checklist mark</code></div>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-zinc-500 border-b border-zinc-800">
                  <tr>
                    <th className="text-left py-2 px-2">row_key</th>
                    <th className="text-left py-2 px-2">label</th>
                    <th className="text-right py-2 px-2">total</th>
                    <th className="text-right py-2 px-2">🟢</th>
                    <th className="text-right py-2 px-2">🟡</th>
                    <th className="text-right py-2 px-2">🔴</th>
                    <th className="text-right py-2 px-2">% red</th>
                  </tr>
                </thead>
                <tbody>
                  {topReds.map((r) => (
                    <tr key={r.row_key} className="border-b border-zinc-900 hover:bg-zinc-900/30">
                      <td className="py-2 px-2 font-mono text-xs">{r.row_key}</td>
                      <td className="py-2 px-2 text-zinc-300">{r.row_label}</td>
                      <td className="py-2 px-2 text-right text-zinc-400">{r.total_marked}</td>
                      <td className="py-2 px-2 text-right text-emerald-400">{r.greens}</td>
                      <td className="py-2 px-2 text-right text-amber-400">{r.yellows}</td>
                      <td className="py-2 px-2 text-right text-red-400 font-medium">{r.reds}</td>
                      <td className="py-2 px-2 text-right">
                        <Badge
                          variant="outline"
                          className={
                            Number(r.pct_red) >= 50
                              ? "bg-red-500/15 text-red-300 border-red-500/30"
                              : Number(r.pct_red) >= 25
                                ? "bg-amber-500/15 text-amber-300 border-amber-500/30"
                                : "bg-zinc-800 text-zinc-300"
                          }
                        >
                          {r.pct_red ?? "—"}%
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BookOpen className="h-5 w-5 text-emerald-400" /> Sorpresas resueltas (insumo Anexo D)
          </CardTitle>
          <CardDescription>
            Lecciones aprendidas que entran al catálogo <code className="bg-zinc-800 px-1 rounded">catalog/known-mismatches-pull.md</code>
          </CardDescription>
        </CardHeader>
        <CardContent>
          {resolved.length === 0 ? (
            <div className="rounded-md bg-zinc-900/40 p-6 text-center text-sm text-zinc-500">
              <Lightbulb className="h-8 w-8 text-zinc-600 mx-auto mb-2" />
              Sin sorpresas resueltas todavía. El catálogo crece con cada <code className="bg-zinc-800 px-1 rounded">/factory-close</code>.
            </div>
          ) : (
            <div className="space-y-2">
              {resolved.map((s, i) => (
                <div key={i} className="rounded-md border border-emerald-500/20 bg-emerald-500/5 p-3">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{s.title}</span>
                    <div className="flex items-center gap-2">
                      {s.catalog_anexo && (
                        <Badge variant="outline" className="text-[10px]">Anexo {s.catalog_anexo}</Badge>
                      )}
                      <Badge variant="outline" className="text-[10px]">{s.slug}</Badge>
                    </div>
                  </div>
                  {s.resolution_notes && (
                    <div className="text-xs text-zinc-400 mt-1">{s.resolution_notes}</div>
                  )}
                  <div className="text-[10px] text-zinc-600 mt-1">
                    resuelta · {s.resolved_at ? new Date(s.resolved_at).toLocaleDateString("es-ES") : ""}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function Count({ label, value }: { label: string; value: string }) {
  return (
    <Card className="p-3">
      <div className="text-[10px] uppercase tracking-wider text-zinc-500">{label}</div>
      <div className="text-2xl font-bold mt-0.5">{value}</div>
    </Card>
  );
}
