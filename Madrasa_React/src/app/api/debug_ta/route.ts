import { query } from '@/lib/db';
import { NextRequest } from 'next/server';

export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const sql = url.searchParams.get('query') || 'SHOW TABLES';
  try {
    const res = await query(sql);
    return new Response(JSON.stringify(res));
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }));
  }
}
