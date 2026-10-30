/**
 * Helper to generate provider-compatible JSON paths for Prisma queries.
 *
 * PostgreSQL / SQLite use string array: ['path', 'to', 'key']
 * MySQL / MariaDB use JSON path string: '$.path.to.key'
 */
export function isMysql(provider?: string): boolean {
  const p = (provider || process.env.DATABASE_PROVIDER || 'postgresql').toLowerCase();
  return p === 'mysql';
}

export function jsonPath(path: string | string[], provider?: string): any {
  const mysql = isMysql(provider);

  if (Array.isArray(path)) {
    return mysql ? `$.${path.join('.')}` : path;
  }

  const cleanPath = path.replace(/^\$\.?/, '');
  return mysql ? `$.${cleanPath}` : cleanPath.split('.');
}
