const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('widget', {
  refresh: () => ipcRenderer.invoke('refresh'),
  onState: (handler) => ipcRenderer.on('state', (_, state) => handler(state)),
  onScene: (handler) => ipcRenderer.on('scene', (_, scene) => handler(scene)),
});
