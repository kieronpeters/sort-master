#!/usr/bin/env node
// FlowQuery board client for the Sort Master release cycle.
// The token is read from a file and is never printed, logged or committed.
//
// Usage:
//   node tools/flowquery.mjs board
//   node tools/flowquery.mjs tasks <status> [limit]
//   node tools/flowquery.mjs task <id>
//   node tools/flowquery.mjs comment <id> <body|@filePath>
//   node tools/flowquery.mjs move <id> <status> [position]
//   node tools/flowquery.mjs create <title> <description|@filePath>

import fs from 'node:fs';
import path from 'node:path';

const BASE = 'https://flowquery.workstack.workers.dev/api/v1/agent';
const TOKEN_FILE = 'C:\\Users\\Asus\\source\\repos\\FlowQuery\\.agent-token';

function token() {
  const raw = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
  if (!raw) throw new Error('Agent token file is empty.');
  return raw;
}

function body(arg) {
  if (arg && arg.startsWith('@')) return fs.readFileSync(path.resolve(arg.slice(1)), 'utf8');
  return arg ?? '';
}

async function call(method, suffix, payload) {
  const res = await fetch(`${BASE}${suffix}`, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      'Content-Type': 'application/json',
      'User-Agent': 'sort-master-release-bot',
    },
    body: payload ? JSON.stringify(payload) : undefined,
  });
  const text = await res.text();
  let parsed;
  try { parsed = JSON.parse(text); } catch { parsed = { raw: text }; }
  return { status: res.status, body: parsed };
}

const [cmd, ...rest] = process.argv.slice(2);

function out(obj) {
  process.stdout.write(JSON.stringify(obj, null, 2) + '\n');
}

function summarizeTask(t) {
  return {
    id: t.id,
    title: t.title,
    status: t.status,
    version: t.version,
    priority: t.priority ?? null,
    updatedAt: t.updatedAt ?? null,
    description: (t.description ?? '').slice(0, 400),
  };
}

switch (cmd) {
  case 'board': {
    const r = await call('GET', '/board');
    if (r.status !== 200) { out(r); process.exit(1); }
    const cols = r.body.columns ?? r.body;
    const summary = Array.isArray(cols)
      ? cols.map((c) => ({ name: c.name ?? c.title ?? c.status, count: (c.tasks ?? []).length, id: c.id }))
      : Object.entries(cols).map(([k, v]) => ({ name: k, count: Array.isArray(v) ? v.length : v }));
    out({ status: r.status, columns: summary, raw_keys: Object.keys(r.body) });
    break;
  }
  case 'tasks': {
    const status = rest[0];
    const limit = rest[1] ?? '100';
    const r = await call('GET', `/tasks?status=${encodeURIComponent(status)}&limit=${limit}`);
    if (r.status !== 200) { out(r); process.exit(1); }
    const list = (r.body.tasks ?? r.body).map(summarizeTask);
    out({ status: r.status, count: list.length, tasks: list });
    break;
  }
  case 'task': {
    const r = await call('GET', `/tasks/${rest[0]}`);
    if (r.status !== 200) { out(r); process.exit(1); }
    out(r.body);
    break;
  }
  case 'comment': {
    const r = await call('POST', `/tasks/${rest[0]}/comments`, { body: body(rest[1]) });
    out(r);
    if (r.status >= 300) process.exit(1);
    break;
  }
  case 'move': {
    // move <id> <status> [position] [version]
    // Accept the 3-argument form too, which is easy to type by mistake.
    const hasPosition = rest.length >= 4;
    const position = hasPosition ? Number(rest[2]) : 0;
    const version = Number(hasPosition ? rest[3] : rest[2]);
    if (!Number.isInteger(version) || version <= 0) {
      process.stderr.write('expectedVersion must be a positive integer; pass it explicitly.\n');
      process.exit(2);
    }
    const payload = { status: rest[1], position, expectedVersion: version };
    const r = await call('POST', `/tasks/${rest[0]}/move`, payload);
    out(r);
    if (r.status >= 300) process.exit(1);
    break;
  }
  case 'create': {
    const r = await call('POST', '/tasks', {
      title: rest[0],
      description: body(rest[1]),
      status: 'backlog',
    });
    out(r);
    if (r.status >= 300) process.exit(1);
    break;
  }
  default:
    process.stderr.write('Unknown command. See the header of this file.\n');
    process.exit(2);
}
