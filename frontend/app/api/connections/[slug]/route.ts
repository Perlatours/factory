import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(
  _req: Request,
  ctx: { params: Promise<{ slug: string }> }
) {
  const { slug } = await ctx.params;

  const [connection] = await query(
    `SELECT * FROM connections WHERE slug = $1`,
    [slug]
  );
  if (!connection) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  const hitls = await query(
    `SELECT gate_number, gate_title, status, approver, decided_at, evidence_url, notes
     FROM hitl_gates
     WHERE connection_id = $1
     ORDER BY gate_number`,
    [(connection as { id: number }).id]
  );

  const phaseLog = await query(
    `SELECT from_phase, to_phase, actor, occurred_at, notes
     FROM phase_log
     WHERE connection_id = $1
     ORDER BY occurred_at DESC
     LIMIT 20`,
    [(connection as { id: number }).id]
  );

  const checklistBySection = await query(
    `SELECT section,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE classification IS NULL) AS pending,
            COUNT(*) FILTER (WHERE classification = 'green')  AS green,
            COUNT(*) FILTER (WHERE classification = 'yellow') AS yellow,
            COUNT(*) FILTER (WHERE classification = 'red')    AS red,
            COUNT(*) FILTER (WHERE classification = 'na')     AS na
     FROM checklist_responses
     WHERE connection_id = $1
     GROUP BY section
     ORDER BY section`,
    [(connection as { id: number }).id]
  );

  const surprises = await query(
    `SELECT id, title, description, catalog_anexo, related_row_key,
            resolved, detected_at, resolved_at, resolution_notes
     FROM surprises
     WHERE connection_id = $1
     ORDER BY resolved, detected_at DESC`,
    [(connection as { id: number }).id]
  );

  const actions = await query(
    `SELECT phase, action_type, target_env, outcome, evidence_url, notes, occurred_at
     FROM actions
     WHERE connection_id = $1
     ORDER BY occurred_at DESC
     LIMIT 30`,
    [(connection as { id: number }).id]
  );

  return NextResponse.json({
    connection,
    hitls,
    phaseLog,
    checklistBySection,
    surprises,
    actions,
  });
}
