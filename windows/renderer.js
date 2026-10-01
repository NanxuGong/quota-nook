const el = (id) => document.getElementById(id);
let usage = null;
let scene = 'afternoon';

const quotes = {
  morning: 'Small steps, big ideas.',
  afternoon: 'A calmer mind, a brighter tomorrow.',
  evening: 'Thinking further together.',
};

function duration(ms) {
  if (!Number.isFinite(ms) || ms <= 0) return 'soon';
  const minutes = Math.ceil(ms / 60000);
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const mins = minutes % 60;
  if (days) return `${days}d ${hours}h`;
  if (hours) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

function renderRow(name, quota) {
  const key = name.toLowerCase();
  el(`${key}-bar`).style.width = quota ? `${quota.remaining}%` : '0%';
  el(`${key}-value`).innerHTML = quota ? `${Math.round(quota.remaining)}% <small>left</small>` : '—';
  el(`${key}-reset`).textContent = quota?.resetAt ? `resets in ${duration(quota.resetAt - Date.now())}` : '—';
}

function render() {
  renderRow('Session', usage?.session);
  renderRow('Weekly', usage?.weekly);
  const resets = [usage?.session?.resetAt, usage?.weekly?.resetAt].filter(Number.isFinite).filter((time) => time > Date.now());
  el('next-reset').textContent = resets.length ? `Resets in ${duration(Math.min(...resets) - Date.now())}` : 'Resets in —';
}

window.widget.onState((state) => {
  usage = state.usage;
  el('status').textContent = state.status;
  render();
});
window.widget.onScene((value) => {
  scene = value;
  el('card').className = scene;
  el('quote').textContent = quotes[scene];
  el('sleep').style.display = scene === 'afternoon' ? 'block' : 'none';
});
el('refresh').addEventListener('click', () => window.widget.refresh());
setInterval(render, 30000);
