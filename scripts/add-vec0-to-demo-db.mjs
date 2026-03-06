#!/usr/bin/env node
/**
 * Opens existing static/demo.db (must have users.id, users.content) and adds
 * the vec0 table user_vecs with embeddings of content. Run after create-demo-db.sh.
 * Requires the sqlite-vec native extension (e.g. from @dao-xyz/sqlite3-vec postinstall).
 */
import { createDatabase } from '@dao-xyz/sqlite3-vec';
import { embed } from '../src/lib/deterministic-embedder.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const dbPath = path.join(repoRoot, 'static', 'demo.db');

const DIMENSION = 8;

const db = await createDatabase({ database: dbPath });
await db.open();

let hasVec = false;
try {
  const ver = await db.prepare('SELECT vec_version() AS v');
  const row = ver.get?.();
  hasVec = !!(row && (row.v ?? row[0]));
} catch (_) {}
if (!hasVec) {
  await db.close();
  console.error('sqlite-vec extension not loaded. Install the native extension (see @dao-xyz/sqlite3-vec) and try again.');
  process.exit(1);
}

db.exec(`CREATE VIRTUAL TABLE IF NOT EXISTS user_vecs USING vec0(vector float[${DIMENSION}])`);
const count = (await db.prepare('SELECT COUNT(*) AS n FROM user_vecs')).get?.()?.n ?? 0;
if (count > 0) {
  db.exec('DELETE FROM user_vecs');
}

const selectUsers = await db.prepare('SELECT id, content FROM users');
const insertVec = await db.prepare(
  'INSERT INTO user_vecs(rowid, vector) VALUES(CAST(? AS INTEGER), ?)'
);

const rows = selectUsers.all?.() ?? [];
for (const r of rows) {
  const id = Math.trunc(Number(r.id ?? r[0]));
  const content = r.content ?? r[1] ?? '';
  const vec = embed(content, DIMENSION);
  insertVec.run([id, vec.buffer]);
}

await db.close();
console.log('Added user_vecs to', dbPath);
