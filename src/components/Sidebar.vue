<template>
  <aside id="sidebar">
    <div class="sidebar-section">
      <h2 class="sidebar-label">音乐库</h2>
      <button class="btn-sidebar" @click="addFolder">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
          <line x1="12" y1="11" x2="12" y2="17"/><line x1="9" y1="14" x2="15" y2="14"/>
        </svg>
        <span>添加文件夹</span>
      </button>
      <p class="queue-hint">
        切换文件夹只会改变当前可见歌曲；“上一首/下一首”会继续沿用开始播放时生成的队列。
      </p>
      <ul class="folder-list">
        <li
          v-for="(folder, i) in player.state.folders"
          :key="folder.path"
          :class="{ active: player.state.activeFolder === i }"
          @click="selectFolder(i)"
        >
          <span class="folder-name">{{ folder.name }}</span>
          <button class="folder-remove" @click.stop="removeFolder(i)" title="移除">×</button>
        </li>
      </ul>
    </div>
    <div class="sidebar-section sidebar-source">
      <h2 class="sidebar-label">音源脚本</h2>
      <button class="btn-sidebar" @click="$emit('openImport')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
          <polyline points="14 2 14 8 20 8"/>
          <line x1="12" y1="18" x2="12" y2="12"/><line x1="9" y1="15" x2="15" y2="15"/>
        </svg>
        <span>导入音源脚本</span>
      </button>
      <div class="source-status" :style="{ color: sourceStatusColor }">{{ sourceStatus }}</div>
    </div>
  </aside>
</template>

<script setup>
import { usePlayer } from '../composables/usePlayer.js';
const player = usePlayer();

defineEmits(['openImport']);

defineProps({
  sourceStatus: { type: String, default: '未加载音源' },
  sourceStatusColor: { type: String, default: '' },
});

async function addFolder() {
  await player.addFolder();
}
function removeFolder(i) {
  player.removeFolder(i);
}
function selectFolder(i) {
  player.selectFolder(i);
}
</script>

<style scoped>
#sidebar {
  width: var(--sidebar-w); min-width: var(--sidebar-w);
  background-color: var(--surface-container-hex);
  border-right: 1px solid rgba(var(--primary), 0.06);
  display: flex; flex-direction: column;
  overflow-y: auto;
}
.sidebar-section { padding: 12px 10px; }
.sidebar-source { margin-top: auto; border-top: 1px solid rgba(var(--primary), 0.06); }
.sidebar-label {
  font-size: 11px; font-weight: 600; color: var(--text-color-tertiary);
  text-transform: uppercase; letter-spacing: 0.5px; padding: 4px 12px;
  margin-bottom: 4px;
}
.btn-sidebar {
  width: 100%; display: flex; align-items: center; gap: 10px;
  padding: 10px 12px; border: 1px dashed rgba(var(--primary), 0.15);
  border-radius: 10px; background: transparent; color: var(--text-color-secondary);
  font-family: var(--font); font-size: 13px; cursor: pointer;
  transition: all 0.2s var(--bezier);
}
.btn-sidebar:hover { border-color: var(--primary-hex); color: var(--primary-hex); background: rgba(var(--primary), 0.04); }
.queue-hint {
  margin: 8px 4px 4px;
  padding: 0 8px;
  font-size: 11px;
  line-height: 1.5;
  color: var(--text-color-tertiary);
}
.folder-list { list-style: none; margin-top: 6px; }
.folder-list li {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; border-radius: 8px; cursor: pointer;
  font-size: 13px; color: var(--text-color-secondary);
  transition: all 0.15s var(--bezier);
}
.folder-list li:hover { background: rgba(var(--primary), 0.06); color: var(--text-color); }
.folder-list li.active { background: rgba(var(--primary), 0.1); color: var(--primary-hex); font-weight: 500; }
.folder-remove {
  background: none; border: none; color: var(--text-color-tertiary);
  font-size: 18px; cursor: pointer; padding: 0 4px; opacity: 0;
  transition: opacity 0.15s;
}
.folder-list li:hover .folder-remove { opacity: 1; }
.folder-remove:hover { color: #ef4444; }

.source-status {
  font-size: 11px; color: var(--text-color-tertiary);
  padding: 6px 12px; text-align: center;
}
</style>
