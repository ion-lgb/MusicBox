<template>
  <NConfigProvider :theme="darkTheme" :theme-overrides="themeOverrides">
    <NMessageProvider>
      <div id="app-root">
        <Titlebar
          @search="handleSearch"
        />
        <div id="app-layout">
          <Sidebar
            :sourceStatus="sourceStatus"
            :sourceStatusColor="sourceStatusColor"
            @openImport="showImportModal = true"
          />
          <main id="content">
            <SongList
              :searchResults="searchResults"
              :isSearchMode="isSearchMode"
              :searchLoading="searchLoading"
              :playHandler="playSearchResult"
              :exitHandler="exitSearch"
            />
          </main>
        </div>
        <PlayerBar />
        <FullPlayer />
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
import FullPlayer from './components/FullPlayer.vue';
import ImportModal from './components/ImportModal.vue';
import { LxSandbox } from './utils/lx-sandbox.js';
import { searchMusic, fetchPic, fetchLyric } from './utils/musicSdk.js';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { usePlayer } from './composables/usePlayer.js';

const player = usePlayer();

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
const sourceStatus = ref('未加载音源');
const sourceStatusColor = ref('');
let lxSandbox = null;
let lxSources = null;
const searchResults = ref([]);
const isSearchMode = ref(false);
const searchLoading = ref(false);

async function onScriptLoaded(content, scriptUrl) {
  sourceStatus.value = '加载中...';
  sourceStatusColor.value = '';
  try {
    lxSandbox = new LxSandbox();
    lxSources = await lxSandbox.load(content);
    const meta = lxSandbox.meta;
    const names = Object.keys(lxSources).map(k => lxSources[k].name || k).join(', ');
    sourceStatus.value = `✓ ${meta.name || '未命名'} (${names})`;
    sourceStatusColor.value = 'var(--primary-hex)';
    // 持久化脚本 URL，下次启动/HMR 自动重载
    if (scriptUrl) localStorage.setItem('lx_script_url', scriptUrl);
  } catch (err) {
    sourceStatus.value = `✗ ${err.message}`;
    sourceStatusColor.value = '#ef4444';
    lxSandbox = null;
    lxSources = null;
  }
}

async function handleSearch(keyword, source = 'kw') {
  if (!keyword) return;
  searchLoading.value = true;
  isSearchMode.value = true;
  searchResults.value = [];
  try {
    const result = await searchMusic(keyword, 1, source);
    searchResults.value = result?.list || [];
    console.log('[Search] 搜索结果:', searchResults.value.length, '首');
  } catch (err) {
    console.error('[Search] 搜索失败:', err);
    searchResults.value = [];
  } finally {
    searchLoading.value = false;
  }
}

function exitSearch() {
  isSearchMode.value = false;
  searchResults.value = [];
}

async function playSearchResult(song, index, playlist) {
  const source = song.source || 'kw';
  if (!lxSandbox) {
    console.error('[Play] 请先导入音源脚本');
    sourceStatus.value = '✗ 请先导入音源脚本';
    sourceStatusColor.value = '#ef4444';
    return;
  }
  try {
    const url = await lxSandbox.getMusicUrl(source, song, '320k');
    if (!url) throw new Error('获取播放 URL 失败');
    const songInfo = {
      path: url,
      file_name: `${song.name || ''} - ${song.singer || ''}.mp3`,
      title: song.name || '',
      artist: song.singer || '',
      album: song.albumName || song.album || '',
      duration: song.interval || 0,
    };
    const playlistInfo = playlist.map(s => ({
      path: `lx://${s.source || source}/${s.songmid || s.hash || s.name}`,
      file_name: `${s.name || ''} - ${s.singer || ''}.mp3`,
      title: s.name || '',
      artist: s.singer || '',
      album: s.albumName || s.album || '',
      duration: s.interval || 0,
    }));
    playlistInfo[index] = songInfo;
    await invoke('play_url', {
      url,
      songInfo,
      index,
      playlist: playlistInfo,
    });
    // 更新 usePlayer 状态，让 PlayerBar 显示正在播放
    player.state.currentSong = songInfo;
    player.state.isPlaying = true;
    player.state.playbackQueue = playlistInfo;
    player.state.currentQueueIndex = index;
    player.state.currentCover = song.img || '';
    player.state.currentLyric = null;
    player.state.parsedLyric = [];
    player.startPolling();
    // 异步获取歌词（不阻塞播放）
    fetchLyricAndCover(source, song);
  } catch (err) {
    console.error('[Play] FAIL:', err?.message || err);
  }
}

async function fetchLyricAndCover(source, song) {
  // 封面（内置 API）
  try {
    const picUrl = await fetchPic(song);
    if (picUrl) player.state.currentCover = picUrl;
  } catch (e) { /* ignore */ }
  // 歌词（内置 API）
  try {
    const lrc = await fetchLyric(song);
    if (lrc) {
      player.state.currentLyric = { lyric: lrc };
      player.state.parsedLyric = player.parseLrc(lrc);
    }
  } catch (e) {
    console.warn('[Lyric] 获取歌词失败:', e?.message || e);
  }
}

// 启动时自动重载上次导入的脚本
onMounted(async () => {
  const savedUrl = localStorage.getItem('lx_script_url');
  if (savedUrl) {
    try {
      const content = await invoke('fetch_text', { url: savedUrl });
      await onScriptLoaded(content, savedUrl);
      console.log('[LX] 自动重载脚本成功:', savedUrl);
    } catch (err) {
      console.warn('[LX] 自动重载脚本失败:', err);
      sourceStatus.value = '✗ 自动重载失败，请重新导入';
      sourceStatusColor.value = '#ef4444';
    }
  }
  // Vue 渲染完成，显示窗口（避免白屏闪烁）
  getCurrentWindow().show();
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
