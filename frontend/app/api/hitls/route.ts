import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const rows = await query(`
    SELECT c.slug, c.factory, c.display_name,
           h.gate_number, h.gate_title,
           COALESCE(c.owner_hitl, '—') AS owner,
           EXTRACT(EPOCH FROM (NOW() - c.updated_at)) / 86400.0 AS days_waiting,
           c.updated_at
    FROM hitl_gates h
    JOIN connections c ON c.id = h.connection_id
    WHERE h.status = 'pending'
      AND c.status IN ('active', 'awaiting_intake')
    ORDER BY c.updated_at;
  `);
  return NextResponse.json(rows);
}
