#!/usr/bin/env node
// Generates per-agent MCP configs and project skill copies from
// .agents/mcp-servers.json. Everything it writes is gitignored, because the
// output embeds absolute binary paths resolved on this machine.
//
//   node .agents/sync.mjs            write
//   node .agents/sync.mjs --check    report drift, exit 1 if any
//   node .agents/sync.mjs --skip-codex   leave ~/.codex/config.toml alone
//
// Runs on Node 18+ with no dependencies.

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const checkOnly = process.argv.includes('--check');
const skipCodex = process.argv.includes('--skip-codex');

const manifest = JSON.parse(
  fs.readFileSync(path.join(repoRoot, '.agents', 'mcp-servers.json'), 'utf8'),
);

// Qoder already has every server at user scope, and its project scope is stored
// by the app rather than in a repo file, so there is nothing to generate.
// Serena's --context comes from the manifest's contextByAgent, not from here, so
// there is one source of truth for it.
//
// `style` describes how strictly each agent wants its entries typed:
//   plain       {url} / {command,args}        Antigravity, Gemini CLI, Cursor
//   typed-http  {type:"http",url} / {command,args}   Claude Code
//   typed-both  {type:"http",url} / {type:"stdio",command,args}   VS Code
//
// `httpKey` overrides the remote-server key, which is not `url` everywhere:
// Gemini CLI validates its settings against `httpUrl` and rejects `url`.
const agents = {
  antigravity: {
    label: 'Antigravity',
    mcpFile: '.agents/plugins/vernet-toolkit/mcp_config.json',
    mcpKey: 'mcpServers',
    style: 'plain',
    skillsDir: '.agents/skills',
  },
  claude: {
    label: 'Claude Code',
    mcpFile: '.mcp.json',
    mcpKey: 'mcpServers',
    style: 'typed-http',
    skillsDir: '.claude/skills',
  },
  vscode: {
    label: 'VS Code / Copilot',
    mcpFile: '.vscode/mcp.json',
    mcpKey: 'servers',
    style: 'typed-both',
    skillsDir: null,
  },
  gemini: {
    label: 'Gemini CLI',
    mcpFile: '.gemini/settings.json',
    mcpKey: 'mcpServers',
    style: 'plain',
    httpKey: 'httpUrl',
    skillsDir: null,
  },
  codex: {
    label: 'Codex',
    mcpFile: null,
    style: 'codex-cli',
    skillsDir: '.codex/skills',
  },
  cursor: {
    label: 'Cursor',
    mcpFile: '.cursor/mcp.json',
    mcpKey: 'mcpServers',
    style: 'plain',
    skillsDir: '.cursor/skills',
  },
};

const expandHome = (p) =>
  p === '~' ? os.homedir() : p.startsWith('~/') ? path.join(os.homedir(), p.slice(2)) : p;

function resolveBinary(server) {
  for (const candidate of server.candidates ?? []) {
    const abs = expandHome(candidate);
    try {
      fs.accessSync(abs, fs.constants.X_OK);
      return abs;
    } catch {
      // fall through to the next candidate
    }
  }
  const found = spawnSync('command', ['-v', server.bin], {
    shell: true,
    encoding: 'utf8',
  });
  const resolved = (found.stdout ?? '').trim().split('\n')[0];
  return resolved || null;
}

const resolved = new Map();
const unresolved = [];
for (const [name, server] of Object.entries(manifest.servers)) {
  if (server.transport !== 'stdio') continue;
  const bin = resolveBinary(server);
  if (bin) resolved.set(name, bin);
  else unresolved.push(name);
}

function substitute(server, agentId) {
  const context = server.contextByAgent?.[agentId] ?? 'desktop-app';
  return (server.args ?? []).map((arg) =>
    arg.replaceAll('{{context}}', context).replaceAll('{{projectDir}}', repoRoot),
  );
}

function renderServers(agentId, agent) {
  const out = {};
  const httpKey = agent.httpKey ?? 'url';
  for (const [name, server] of Object.entries(manifest.servers)) {
    if (server.transport === 'http') {
      out[name] =
        agent.style === 'plain'
          ? { [httpKey]: server.url }
          : { type: 'http', [httpKey]: server.url };
      continue;
    }
    const bin = resolved.get(name);
    if (!bin) continue;
    const args = substitute(server, agentId);
    const entry = args.length ? { command: bin, args } : { command: bin };
    out[name] = agent.style === 'typed-both' ? { type: 'stdio', ...entry } : entry;
  }
  return out;
}

const drift = [];
const written = [];

function writeJson(relPath, key, value) {
  const abs = path.join(repoRoot, relPath);
  const existing = fs.existsSync(abs)
    ? JSON.parse(fs.readFileSync(abs, 'utf8'))
    : {};
  const next = { ...existing, [key]: value };
  const body = `${JSON.stringify(next, null, 2)}\n`;
  if (fs.existsSync(abs) && fs.readFileSync(abs, 'utf8') === body) {
    written.push(`${relPath} (unchanged)`);
    return;
  }
  if (checkOnly) {
    drift.push(relPath);
    return;
  }
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, body);
  written.push(relPath);
}

function mirrorSkills(sourceRel, targetRel) {
  const source = path.join(repoRoot, sourceRel);
  const target = path.join(repoRoot, targetRel);
  if (!fs.existsSync(source)) return [];
  const names = fs
    .readdirSync(source, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
    .map((entry) => entry.name);

  if (checkOnly) {
    const missing = names.filter(
      (name) => !fs.existsSync(path.join(target, name, 'SKILL.md')),
    );
    if (missing.length) drift.push(`${targetRel} (${missing.length} missing)`);
    return names;
  }

  fs.mkdirSync(target, { recursive: true });
  for (const stale of fs.readdirSync(target)) {
    if (!names.includes(stale)) fs.rmSync(path.join(target, stale), { recursive: true, force: true });
  }
  for (const name of names) {
    fs.rmSync(path.join(target, name), { recursive: true, force: true });
    fs.cpSync(path.join(source, name), path.join(target, name), { recursive: true });
  }
  return names;
}

function syncCodex(agentId) {
  if (!resolved.size && !Object.values(manifest.servers).some((s) => s.transport === 'http')) {
    return 'skipped (nothing resolved)';
  }
  const codex = spawnSync('codex', ['--version'], { encoding: 'utf8' });
  if (codex.status !== 0) return 'skipped (codex CLI not found)';

  const applied = [];
  for (const [name, server] of Object.entries(manifest.servers)) {
    const argv =
      server.transport === 'http'
        ? [
            'mcp',
            'add',
            name,
            '--url',
            server.url,
            ...(server.bearerTokenEnvVar
              ? ['--bearer-token-env-var', server.bearerTokenEnvVar]
              : []),
          ]
        : (() => {
            const bin = resolved.get(name);
            if (!bin) return null;
            return ['mcp', 'add', name, '--', bin, ...substitute(server, agentId)];
          })();
    if (!argv) continue;

    if (!checkOnly) {
      spawnSync('codex', ['mcp', 'remove', name], { encoding: 'utf8' });
      const add = spawnSync('codex', argv, { encoding: 'utf8' });
      if (add.status !== 0) {
        applied.push(`${name} FAILED: ${(add.stderr ?? '').trim().split('\n')[0]}`);
        continue;
      }
    }
    applied.push(name);
  }
  if (checkOnly) return `would set ${applied.join(', ')}`;
  // `codex mcp add` rewrites the whole file, so hand-written comments and key
  // order in ~/.codex/config.toml do not survive a sync.
  return `set ${applied.join(', ')} (rewrote ~/.codex/config.toml; comments not preserved)`;
}

const skillSource = manifest.skills?.source ?? '.qoder/skills';
const results = [];

for (const [id, agent] of Object.entries(agents)) {
  const notes = [];
  if (agent.mcpFile) {
    writeJson(agent.mcpFile, agent.mcpKey, renderServers(id, agent));
    notes.push(agent.mcpFile);
  }
  // Codex has no project-scope MCP file, so syncing it rewrites the global
  // ~/.codex/config.toml. --skip-codex keeps that out of a repo-local refresh.
  if (id === 'codex') notes.push(skipCodex ? 'config.toml untouched (--skip-codex)' : syncCodex(id));
  if (agent.skillsDir) {
    const names = mirrorSkills(skillSource, agent.skillsDir);
    notes.push(`${agent.skillsDir} (${names.length} skills)`);
  }
  results.push([agent.label, notes.join('; ')]);
}

console.log(`Repo: ${repoRoot}`);
console.log(`Resolved binaries: ${[...resolved.entries()].map(([n, b]) => `${n}=${b}`).join(' ')}`);
if (unresolved.length) {
  console.log(`UNRESOLVED (skipped everywhere): ${unresolved.join(', ')}`);
  console.log('  Add a candidate path to .agents/mcp-servers.json, or put the binary on PATH.');
}
console.log('');
for (const [label, note] of results) console.log(`  ${label.padEnd(18)} ${note}`);
console.log('');

const httpNames = Object.entries(manifest.servers)
  .filter(([, s]) => s.transport === 'http')
  .map(([n]) => n);
if (httpNames.length) {
  console.log(`Remote servers (${httpNames.join(', ')}) are written without credentials.`);
  console.log('Authenticate inside each app; never commit a token to these files.');
  console.log('');
}

if (checkOnly) {
  if (drift.length) {
    console.log(`Drift detected in ${drift.length} target(s): ${drift.join(', ')}`);
    console.log('Run `node .agents/sync.mjs` to regenerate.');
    process.exit(1);
  }
  console.log('In sync.');
} else {
  console.log('Restart each agent for MCP changes to take effect.');
}
