const { app, BrowserWindow, Tray, Menu, ipcMain, screen, nativeImage } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { readUsage } = require('./usage');

const WIDTH = 784;
const HEIGHT = 268;
let window;
let tray;
let state = { usage: null, status: 'Connecting to Codex…' };
let refreshing = false;
let pinned = false;
let chosenScene = 'auto';
let lastInside = 0;

if (!app.requestSingleInstanceLock()) app.quit();
else app.on('second-instance', () => showWindow());

function sceneNow() {
  if (chosenScene !== 'auto') return chosenScene;
  const hour = new Date().getHours();
  return hour >= 5 && hour < 11 ? 'morning' : hour >= 11 && hour < 17 ? 'afternoon' : 'evening';
}

function sendState() {
  if (!window || window.isDestroyed()) return;
  window.webContents.send('state', state);
  window.webContents.send('scene', sceneNow());
}

function positionWindow() {
  const pointer = screen.getCursorScreenPoint();
  const display = screen.getDisplayNearestPoint(pointer);
  window.setBounds({ x: Math.round(display.bounds.x + (display.bounds.width - WIDTH) / 2), y: display.bounds.y + 3, width: WIDTH, height: HEIGHT });
}

function showWindow() {
  if (!window || window.isDestroyed()) return;
  positionWindow();
  window.showInactive();
  sendState();
}

function setScene(scene) {
  chosenScene = scene;
  window.webContents.send('scene', sceneNow());
  updateMenu();
}

function updateMenu() {
  if (!tray) return;
  const loginEnabled = app.getLoginItemSettings().openAtLogin;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Show Quota Nook', click: () => { pinned = true; showWindow(); } },
    { label: 'Refresh quota', click: refresh },
    { type: 'separator' },
    { label: 'Background', submenu: [
      { label: 'Automatic', type: 'radio', checked: chosenScene === 'auto', click: () => setScene('auto') },
      { label: 'Morning', type: 'radio', checked: chosenScene === 'morning', click: () => setScene('morning') },
      { label: 'Afternoon', type: 'radio', checked: chosenScene === 'afternoon', click: () => setScene('afternoon') },
      { label: 'Evening', type: 'radio', checked: chosenScene === 'evening', click: () => setScene('evening') },
    ] },
    { label: 'Start with Windows', type: 'checkbox', checked: loginEnabled, click: ({ checked }) => {
      app.setLoginItemSettings({ openAtLogin: checked, path: process.execPath });
      updateMenu();
    } },
    { type: 'separator' },
    { label: 'Quit', click: () => app.quit() },
  ]));
}

async function refresh() {
  if (refreshing) return;
  refreshing = true;
  state.status = 'Syncing…';
  sendState();
  try {
    state.usage = await readUsage();
    state.status = 'synced just now';
    try { fs.writeFileSync(path.join(app.getPath('userData'), 'usage.json'), JSON.stringify(state.usage)); } catch {}
  } catch (error) {
    state.status = state.usage ? `offline · ${error.message}` : error.message;
  } finally {
    refreshing = false;
    sendState();
  }
}

function monitorPointer() {
  const pointer = screen.getCursorScreenPoint();
  const display = screen.getDisplayNearestPoint(pointer);
  const center = display.bounds.x + display.bounds.width / 2;
  const atTop = pointer.y <= display.bounds.y + 5 && Math.abs(pointer.x - center) < 165;
  if (atTop) showWindow();
  if (!window.isVisible() || pinned) return;
  const b = window.getBounds();
  const inside = pointer.x >= b.x && pointer.x < b.x + b.width && pointer.y >= b.y && pointer.y < b.y + b.height;
  if (inside || atTop) lastInside = Date.now();
  else if (Date.now() - lastInside > 1200) window.hide();
}

app.whenReady().then(() => {
  app.setName('Quota Nook');
  try { state.usage = JSON.parse(fs.readFileSync(path.join(app.getPath('userData'), 'usage.json'), 'utf8')); state.status = 'cached · syncing…'; } catch {}
  window = new BrowserWindow({ width: WIDTH, height: HEIGHT, frame: false, transparent: true, resizable: false, skipTaskbar: true, alwaysOnTop: true, show: false,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true } });
  window.loadFile(path.join(__dirname, 'index.html'));
  window.webContents.on('did-finish-load', sendState);
  window.webContents.on('context-menu', () => tray.popUpContextMenu());
  window.on('blur', () => { if (pinned) { pinned = false; setTimeout(() => { if (window && !window.isDestroyed()) window.hide(); }, 400); } });
  const icon = nativeImage.createFromPath(path.join(__dirname, 'assets', 'tray.png'));
  tray = new Tray(icon);
  tray.setToolTip('Quota Nook');
  tray.on('click', () => { pinned = !pinned; pinned ? showWindow() : window.hide(); });
  updateMenu();
  ipcMain.handle('refresh', () => refresh());
  setInterval(monitorPointer, 350);
  setInterval(refresh, 120000);
  setInterval(() => { if (chosenScene === 'auto') window.webContents.send('scene', sceneNow()); }, 60000);
  refresh();
  showWindow();
});

app.on('window-all-closed', (event) => event.preventDefault());
