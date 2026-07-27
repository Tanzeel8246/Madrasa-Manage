import mysql from 'mysql2/promise';

// Create a connection pool for the Super Admin database
// In a multi-tenant system, this DB stores tenant info (Madrasas)
export const pool = mysql.createPool({
  host: process.env.MADRASA_DB_HOST || 'localhost',
  user: process.env.MADRASA_DB_USER || 'mamfss_madrasa',
  password: process.env.MADRASA_DB_PASSWORD || '',
  database: process.env.MADRASA_DB_NAME || 'mamfss_madrasa', // Super Admin DB for now
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

/**
 * Executes a query on the main database
 */
export async function query(sql: string, values?: any[]) {
  const [rows, fields] = await pool.execute(sql, values);
  return rows;
}

/**
 * Gets a dedicated connection for a specific tenant (Madrasa)
 * This allows connecting to different databases (Option B) dynamically
 */
export async function getTenantConnection(dbName: string) {
  return mysql.createConnection({
    host: process.env.MADRASA_DB_HOST || 'localhost',
    user: process.env.MADRASA_DB_USER || 'mamfss_madrasa',
    password: process.env.MADRASA_DB_PASSWORD || '',
    database: dbName,
  });
}
