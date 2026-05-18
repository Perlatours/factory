import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const topReds = await query(`
    SELECT row_key, row_label,
           COUNT(*) AS total_marked,
           COUNT(*) FILTER (WHERE classification = 'red')    AS reds,
           COUNT(*) FILTER (WHERE classification = 'yellow') AS yellows,
           COUNT(*) FILTER (WHERE classification = 'green')  AS greens,
           ROUND(100.0 * COUNT(*) FILTER (WHERE classification = 'red') / NULLIF(COUNT(*), 0), 1) AS pct_red
    FROM checklist_responses
    WHERE classification IS NOT NULL
    GROUP BY row_key, row_label
    HAVING COUNT(*) >= 1
    ORDER BY pct_red DESC NULLS LAST, total_marked DESC
    LIMIT 30;
  `);

  const resolvedSurprises = await query(`
    SELECT s.title, s.catalog_anexo, c.slug, s.resolution_notes, s.resolved_at
    FROM surprises s
    JOIN connections c ON c.id = s.connection_id
    WHERE s.resolved
    ORDER BY s.resolved_at DESC
    LIMIT 30;
  `);

  const counts = await query(`
    SELECT
      (SELECT COUNT(*) FROM connections) AS total_conns,
      (SELECT COUNT(*) FROM connections WHERE status = 'done') AS done_conns,
      (SELECT COUNT(*) FROM connections WHERE status = 'active') AS active_conns,
      (SELECT COUNT(*) FROM checklist_responses WHERE classification IS NOT NULL) AS marked_rows,
      (SELECT COUNT(*) FROM surprises) AS total_surprises;
  `);

  return NextResponse.json({ topReds, resolvedSurprises, counts: counts[0] });
}
