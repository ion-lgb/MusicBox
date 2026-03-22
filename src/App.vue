<template>
  <NConfigProvider :theme="darkTheme" :theme-overrides="themeOverrides">
    <NMessageProvider>
      <div id="app-root">
        <Titlebar
          v-model:searchEnabled="searchEnabled"
          @search="handleSearch"
        />
        <div id="app-layout">
          <Sidebar
            :sourceStatus="sourceStatus"
            :sourceStatusColor="sourceStatusColor"
            @openImport="showImportModal = true"
          />
          <main id="content">
            <SongList />
          </main>
        </div>
        <PlayerBar />
        <ImportModal v-model:show="showImportModal" @loaded="onScriptLoaded" />
      </div>
    </NMessageProvider>
  </NConfigProvider>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { darkTheme } from 'naive-ui';
import { NConfigProvider, NMessageProvider } from 'naive-ui';
import Titlebar from './components/Titlebar.vue';
import Sidebar from './components/Sidebar.vue';
import SongList from './components/SongList.vue';
import PlayerBar from './components/PlayerBar.vue';
import ImportModal from './components/ImportModal.vue';
import { LxSandbox } from './utils/lx-sandbox.js';

// SPlayer 风格主题覆盖
const themeOverrides = {
  common: {
    primaryColor: 'rgb(51, 94, 234)',
    primaryColorHover: 'rgb(71, 114, 254)',
    primaryColorPressed: 'rgb(41, 84, 224)',
    borderRadius: '12px',
    fontFamily: '"HarmonyOS Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif',
  },
  Slider: {
    fillColor: 'rgb(51, 94, 234)',
    fillColorHover: 'rgb(51, 94, 234)',
    handleColor: '#fff',
    handleSize: '14px',
    railHeight: '3px',
  },
};

// ---- 音源状态 ----
const showImportModal = ref(false);
const searchEnabled = ref(false);
const sourceStatus = ref('未加载音源');
const sourceStatusColor = ref('');
let lxSandbox = null;
let lxSources = null;

async function onScriptLoaded(content) {
  sourceStatus.value = '加载中...';
  sourceStatusColor.value = '';
  try {
    lxSandbox = new LxSandbox();
    lxSources = await lxSandbox.load(content);
    const meta = lxSandbox.meta;
    const names = Object.keys(lxSources).map(k => lxSources[k].name || k).join(', ');
    sourceStatus.value = `✓ ${meta.name || '未命名'} (${names})`;
    sourceStatusColor.value = 'var(--primary-hex)';
    searchEnabled.value = true;
    // 持久化
    localStorage.setItem('lx_script', content);
  } catch (err) {
    sourceStatus.value = `✗ ${err.message}`;
    sourceStatusColor.value = '#ef4444';
    lxSandbox = null;
    lxSources = null;
  }
}

function handleSearch(keyword) {
  if (!keyword || !lxSandbox || !lxSources) return;
  console.log('[LX] 搜索:', keyword);
  sourceStatus.value = '搜索功能需要搜索 API 支持';
  setTimeout(() => {
    if (lxSandbox?.ready) {
      const names = Object.keys(lxSources).map(k => lxSources[k].name || k).join(', ');
      sourceStatus.value = `✓ ${lxSandbox.meta?.name || '未命名'} (${names})`;
    }
  }, 3000);
}

// 自动加载上次保存的脚本
onMounted(async () => {
  const saved = localStorage.getItem('lx_script');
  if (saved) {
    await onScriptLoaded(saved);
  }
});
</script>

<style>
#app-root {
  display: flex; flex-direction: column;
  height: 100vh; overflow: hidden;
  background: var(--background);
}
#app-layout {
  display: flex; flex: 1; overflow: hidden;
  margin-top: var(--titlebar-h);
}
#content {
  flex: 1; overflow-y: auto;
  padding-bottom: var(--player-h);
}
</style>
