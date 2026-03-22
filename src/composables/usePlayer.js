/**
 * usePlayer — 播放器全局状态 + Tauri invoke 封装
 * 使用 Vue reactivity，所有组件共享同一份状态
 */
import { reactive, ref } from 'vue';

const { invoke } = window.__TAURI__.core;

// ---- 全局响应式状态（单例） ----
const state = reactive({
  folders: [],
  allSongs: [],
  displayedSongs: [],
  activeFolder: null,
  isPlaying: false,
  currentSong: null,
  currentIndex: null,
  position: 0,
  duration: 0,
  volume: 0.8,
  pollTimer: null,
  isDraggingProgress: false,
});

// ---- 文件夹管理 ----
async function addFolder() {
  try {
    const selected = await invoke('pick_folder');
    if (!selected) return;
    if (state.folders.some(f => f.path === selected)) return;

    const songs = await invoke('scan_music_dir', { path: selected });
    const parts = selected.replace(/\\/g, '/').replace(/\/$/, '').split('/');
    state.folders.push({
      path: selected,
      name: parts[parts.length - 1] || selected,
      songs,
    });
    rebuildAllSongs();
  } catch (err) {
    console.error('添加文件夹失败:', err);
  }
}

function removeFolder(index) {
  state.folders.splice(index, 1);
  if (state.activeFolder === index) state.activeFolder = null;
  else if (state.activeFolder > index) state.activeFolder--;
  rebuildAllSongs();
}

function selectFolder(index) {
  state.activeFolder = state.activeFolder === index ? null : index;
  rebuildAllSongs();
}

function rebuildAllSongs() {
  if (state.activeFolder !== null && state.folders[state.activeFolder]) {
    state.displayedSongs = state.folders[state.activeFolder].songs;
  } else {
    state.allSongs = state.folders.flatMap(f => f.songs);
    state.displayedSongs = state.allSongs;
  }
}

// ---- 播放控制 ----
async function playSongAt(index) {
  const song = state.displayedSongs[index];
  if (!song) return;
  try {
    await invoke('play_song', {
      path: song.path,
      index,
      playlist: state.displayedSongs,
    });
    state.isPlaying = true;
    state.currentSong = song;
    state.currentIndex = index;
    startPolling();
  } catch (err) {
    console.error('播放失败:', err);
  }
}

async function togglePlayPause() {
  if (!state.currentSong) return;
  try {
    if (state.isPlaying) {
      await invoke('pause_song');
      state.isPlaying = false;
    } else {
      await invoke('resume_song');
      state.isPlaying = true;
    }
  } catch (err) {
    console.error('暂停/恢复失败:', err);
  }
}

async function playNext() {
  try {
    const song = await invoke('play_next');
    if (song) {
      state.currentSong = song;
      state.currentIndex = state.displayedSongs.findIndex(s => s.path === song.path);
      state.isPlaying = true;
      startPolling();
    }
  } catch (err) {
    console.error('下一首失败:', err);
  }
}

async function playPrev() {
  try {
    const song = await invoke('play_prev');
    if (song) {
      state.currentSong = song;
      state.currentIndex = state.displayedSongs.findIndex(s => s.path === song.path);
      state.isPlaying = true;
      startPolling();
    }
  } catch (err) {
    console.error('上一首失败:', err);
  }
}

async function seekTo(pos) {
  try {
    await invoke('seek_to', { position: pos });
  } catch (err) {
    console.error('跳转失败:', err);
  }
}

async function setVolume(vol) {
  state.volume = vol;
  try {
    await invoke('set_volume', { volume: vol });
  } catch (err) {
    console.error('设置音量失败:', err);
  }
}

// ---- 状态轮询 ----
function startPolling() {
  stopPolling();
  state.pollTimer = setInterval(pollStatus, 500);
}

function stopPolling() {
  if (state.pollTimer) {
    clearInterval(state.pollTimer);
    state.pollTimer = null;
  }
}

async function pollStatus() {
  try {
    const status = await invoke('get_player_status');
    if (!state.isDraggingProgress) {
      state.position = status.position;
    }
    state.duration = status.duration;
    state.isPlaying = status.is_playing;

    if (status.is_stopped && state.currentSong) {
      await playNext();
    }
  } catch (err) {
    // ignore polling errors
  }
}

// ---- 键盘快捷键 ----
function initKeyboard() {
  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    switch (e.code) {
      case 'Space':
        e.preventDefault();
        togglePlayPause();
        break;
      case 'ArrowRight':
        if (e.ctrlKey) playNext();
        break;
      case 'ArrowLeft':
        if (e.ctrlKey) playPrev();
        break;
    }
  });
}

// 初始化键盘监听（调用一次）
let _keyboardInited = false;
function ensureKeyboard() {
  if (!_keyboardInited) {
    initKeyboard();
    _keyboardInited = true;
  }
}

// ---- Composable 导出 ----
export function usePlayer() {
  ensureKeyboard();
  return {
    ...state,
    // 让模板能直接访问 reactive 属性
    get folders() { return state.folders; },
    get displayedSongs() { return state.displayedSongs; },
    get isPlaying() { return state.isPlaying; },
    get currentSong() { return state.currentSong; },
    get currentIndex() { return state.currentIndex; },
    get position() { return state.position; },
    get duration() { return state.duration; },
    get volume() { return state.volume; },
    get activeFolder() { return state.activeFolder; },
    get isDraggingProgress() { return state.isDraggingProgress; },
    set isDraggingProgress(v) { state.isDraggingProgress = v; },
    set position(v) { state.position = v; },

    addFolder,
    removeFolder,
    selectFolder,
    playSongAt,
    togglePlayPause,
    playNext,
    playPrev,
    seekTo,
    setVolume,
    startPolling,
    stopPolling,
    state, // 直接暴露 reactive 对象供模板绑定
  };
}
