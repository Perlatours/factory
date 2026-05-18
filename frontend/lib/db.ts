import { Pool } from "pg";

declare global {
  // eslint-disable-next-line no-var
  var _factoryPool: Pool | undefined;
}

// Singleton pool, read-only user
export const pool =
  global._factoryPool ??
  new Pool({
    host: process.env.FACTORY_DB_HOST ?? "localhost",
    port: Number(process.env.FACTORY_DB_PORT ?? 5433),
    database: process.env.FACTORY_DB_NAME ?? "factory",
    user: process.env.FACTORY_DB_USER ?? "factory_reader",
    password: process.env.FACTORY_DB_PASSWORD ?? "factory_reader_local",
    max: 5,
  });

if (process.env.NODE_ENV !== "production") {
  global._factoryPool = pool;
}

export async function query<T = Record<string, unknown>>(
  sql: string,
  params: unknown[] = []
): Promise<T[]> {
  const result = await pool.query(sql, params);
  return result.rows as T[];
}
