const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

function parseRateLimits(result) {
  const limits = result?.rateLimitsByLimitId?.codex ?? result?.rateLimits;
  if (!limits) throw new Error('Codex did not return quota data. Sign in with a ChatGPT account.');
  const read = (window) => window ? {
    remaining: Math.max(0, Math.min(100, 100 - Number(window.usedPercent ?? 100))),
    resetAt: Number(window.resetsAt ?? 0) * 1000,
  } : null;
  return { session: read(limits.primary), weekly: read(limits.secondary), fetchedAt: Date.now() };
}

function findCodex() {
  const candidates = [process.env.CODEX_CLI_PATH];
  if (process.platform === 'win32') {
    const local = process.env.LOCALAPPDATA || '';
    const roaming = process.env.APPDATA || '';
    const home = process.env.USERPROFILE || '';
    candidates.push(
      path.join(roaming, 'npm', 'codex.cmd'),
      path.join(local, 'Microsoft', 'WinGet', 'Links', 'codex.exe'),
      path.join(home, '.local', 'bin', 'codex.exe'),
    );
  }
  for (const file of candidates) if (file && fs.existsSync(file)) return file;
  if (process.platform === 'win32') {
    try {
      const found = execFileSync('where.exe', ['codex'], { windowsHide: true, encoding: 'utf8', timeout: 2000 });
      const file = found.split(/\r?\n/).find((entry) => entry && fs.existsSync(entry));
      if (file) return file;
    } catch {}
  }
  return 'codex';
}

function startCodex(executable) {
  if (process.platform === 'win32' && /\.(cmd|bat)$/i.test(executable)) {
    const child = spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', `"${executable}" app-server`], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    child.usingCmd = true;
    return child;
  }
  return spawn(executable, ['app-server'], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
}

function readUsage() {
  return new Promise((resolve, reject) => {
    const child = startCodex(findCodex());
    let done = false;
    let buffer = '';
    const finish = (error, result) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      if (child.usingCmd && child.pid) {
        spawn('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
      } else child.kill();
      error ? reject(error) : resolve(result);
    };
    const timer = setTimeout(() => finish(new Error('Codex did not respond in time.')), 15000);
    child.on('error', (error) => finish(new Error(`Cannot start Codex CLI: ${error.message}`)));
    child.on('exit', (code) => { if (!done) finish(new Error(`Codex CLI exited (${code}).`)); });
    child.stdout.on('data', (chunk) => {
      buffer += chunk.toString('utf8');
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end).trim();
        buffer = buffer.slice(end + 1);
        if (!line) continue;
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        if (message.id === 1) {
          if (message.error) return finish(new Error(message.error.message || 'Codex initialization failed.'));
          child.stdin.write(JSON.stringify({ method: 'initialized', params: {} }) + '\n');
          child.stdin.write(JSON.stringify({ id: 2, method: 'account/rateLimits/read', params: {} }) + '\n');
        } else if (message.id === 2) {
          try { finish(null, parseRateLimits(message.result)); }
          catch (error) { finish(error); }
        }
      }
    });
    child.stdin.write(JSON.stringify({ id: 1, method: 'initialize', params: { clientInfo: { name: 'codex-usage-widget', version: '1.0.0' }, capabilities: {} } }) + '\n');
  });
}

module.exports = { parseRateLimits, readUsage };
