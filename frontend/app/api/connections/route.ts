import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export const dynamic = "force-dynamic";

export type ConnectionRow = {
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
  owner_hitl: string | null;
  contact_name: string | null;
  contact_email: string | null;
  notes: string | null;
  updated_at: string;
  hitls_pending: string | null;
};

export async function GET() {
  const rows = await query<ConnectionRow>(`
    SELECT c.id, c.slug, c.display_name, c.factory, c.mode, c.is_pilot,
           c.current_phase, c.status, c.dev_status, c.prod_status,
           c.owner_hitl, c.contact_name, c.contact_email, c.notes, c.updated_at,
           (SELECT string_agg('#' || gate_number::text, ',' ORDER BY gate_number)
            FROM hitl_gates h
            WHERE h.connection_id = c.id AND h.status = 'pending') AS hitls_pending
    FROM connections c
    ORDER BY c.current_phase DESC, c.slug;
  `);
  return NextResponse.json(rows);
}
