<template>
  <header id="titlebar">
    <div id="titlebar-drag" data-tauri-drag-region>
      <svg class="titlebar-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
        <path d="M9 18V5l12-2v13"/>
        <circle cx="6" cy="18" r="3"/>
        <circle cx="18" cy="16" r="3"/>
      </svg>
      <span class="titlebar-title">Ion Music Box</span>
    </div>
    <!-- SPlayer 搜索栏 -->
    <div id="titlebar-search">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
        <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
      </svg>
      <input
        v-model="searchQuery"
        type="text"
        :placeholder="searchPlaceholder"
        :disabled="!searchEnabled"
        @keydown.enter="$emit('search', searchQuery)"
      />
    </div>
    <div id="titlebar-controls">
      <button class="titlebar-btn" @click="minimize" title="最小化">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"/></svg>
      </button>
      <button class="titlebar-btn" @click="toggleMaximize" title="最大化">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="5" width="14" height="14" rx="1"/></svg>
      </button>
      <button class="titlebar-btn titlebar-btn--close" @click="close" title="关闭">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="6" y1="6" x2="18" y2="18"/><line x1="6" y1="18" x2="18" y2="6"/></svg>
      </button>
    </div>
  </header>
</template>

<script setup>
import { ref } from 'vue';
const { getCurrentWindow } = window.__TAURI__.window;
const appWindow = getCurrentWindow();

const searchQuery = ref('');
const searchEnabled = defineModel('searchEnabled', { default: false });
const searchPlaceholder = defineModel('searchPlaceholder', { default: '搜索在线音乐...' });

defineEmits(['search']);

const minimize = () => appWindow.minimize();
const toggleMaximize = () => appWindow.toggleMaximize();
const close = () => appWindow.close();
</script>

<style scoped>
#titlebar {
  position: fixed; top: 0; left: 0; right: 0;
  height: var(--titlebar-h);
  display: flex; align-items: center;
  padding: 0 10px;
  background-color: var(--surface-container-hex);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid rgba(var(--primary), 0.06);
  z-index: 100;
}
#titlebar-drag {
  display: flex; align-items: center; gap: 12px;
  flex: 1; height: 100%;
}
.titlebar-icon { color: var(--primary-hex); flex-shrink: 0; }
.titlebar-title { font-size: 13px; font-weight: 600; color: var(--text-color); }

#titlebar-search {
  display: flex; align-items: center; gap: 6px;
  background: rgba(var(--primary), 0.06);
  border: 1px solid rgba(var(--primary), 0.08);
  border-radius: 9999px; padding: 6px 14px;
  transition: all 0.3s var(--bezier);
}
#titlebar-search:focus-within {
  border-color: rgba(var(--primary), 0.3);
  background: rgba(var(--primary), 0.1);
}
#titlebar-search svg { color: var(--text-color-tertiary); flex-shrink: 0; }
#titlebar-search input {
  border: none; background: transparent; outline: none;
  font-family: var(--font); font-size: 13px; color: var(--text-color);
  width: 180px; user-select: text;
}
#titlebar-search input::placeholder { color: var(--text-color-tertiary); }
#titlebar-search input:disabled { opacity: 0.5; cursor: not-allowed; }

#titlebar-controls { display: flex; gap: 2px; margin-left: 8px; }
.titlebar-btn {
  width: 36px; height: 36px; border: none; background: transparent;
  color: var(--text-color-secondary); cursor: pointer; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s var(--bezier);
}
.titlebar-btn svg { width: 16px; height: 16px; }
.titlebar-btn:hover { background: rgba(var(--primary), 0.08); color: var(--text-color); }
.titlebar-btn--close:hover { background: #e81123; color: #fff; }
</style>
