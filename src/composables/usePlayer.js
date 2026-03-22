/**
 * usePlayer — 播放器全局状态 + Tauri invoke 封装
 * 使用 Vue reactivity，所有组件共享同一份状态
 */
import { reactive } from 'vue';

export function buildDisplayedSongs(folders, activeFolder) {
  const allSongs = folders.flatMap(folder => folder.songs);
  const displayedSongs = activeFolder !== null && folders[activeFolder]
    ? folders[activeFolder].songs
    : allSongs;

  return { allSongs, displayedSongs };
}

function isSameSongAtIndex(songs, index, song) {
  return index !== null
    && index !== undefined
    && index >= 0
    && index < songs.length
    && songs[index]?.path === song?.path;
}

function findSongIndex(songs, song, preferredIndex = null) {
  if (!song) return null;
  if (isSameSongAtIndex(songs, preferredIndex, song)) {
    return preferredIndex;
  }

  const index = songs.findIndex(item => item.path === song.path);
  return index >= 0 ? index : null;
}

export function createPlaybackSnapshot(displayedSongs, startIndex) {
  const song = displayedSongs[startIndex];
  if (!song) {
    return {
      playbackQueue: [],
      currentSong: null,
      currentQueueIndex: null,
      currentVisibleIndex: null,
      isCurrentSongVisible: false,
    };
  }

  const playbackQueue = displayedSongs.slice();
  return {
    playbackQueue,
    currentSong: song,
    currentQueueIndex: startIndex,
    ...resolveVisiblePlaybackState(displayedSongs, song, startIndex),
  };
}

export function resolveVisiblePlaybackState(displayedSongs, currentSong, preferredIndex = null) {
  if (!currentSong) {
    return {
      currentVisibleIndex: null,
      isCurrentSongVisible: false,
    };
  }

  const visibleIndex = findSongIndex(displayedSongs, currentSong, preferredIndex);
  return {
    currentVisibleIndex: visibleIndex,
    isCurrentSongVisible: visibleIndex !== null,
  };
}

function getInvoke() {
  const invoke = globalThis.window?.__TAURI__?.core?.invoke;
  if (!invoke) {
    throw new Error('Tauri invoke 不可用');
  }
  return invoke;
}

// ---- 全局响应式状态（单例） ----
const state = reactive({
  folders: [],
  allSongs: [],
  displayedSongs: [],
  playbackQueue: [],
  activeFolder: null,
  isPlaying: false,
  currentSong: null,
  currentQueueIndex: null,
  currentVisibleIndex: null,
  isCurrentSongVisible: false,
  position: 0,
  duration: 0,
  volume: 0.8,
  pollTimer: null,
  isDraggingProgress: false,
});

function syncVisiblePlaybackState(song = state.currentSong, preferredIndex = state.currentVisibleIndex) {
  const { currentVisibleIndex, isCurrentSongVisible } = resolveVisiblePlaybackState(state.displayedSongs, song, preferredIndex);
  state.currentVisibleIndex = currentVisibleIndex;
  state.isCurrentSongVisible = isCurrentSongVisible;
}

function syncDisplayedSongs() {
  const { allSongs, displayedSongs } = buildDisplayedSongs(state.folders, state.activeFolder);
  state.allSongs = allSongs;
  state.displayedSongs = displayedSongs;
  syncVisiblePlaybackState();
}

function syncQueueIndex(song = state.currentSong, preferredIndex = state.currentQueueIndex) {
  if (!song) {
    state.currentQueueIndex = null;
    return;
  }

  state.currentQueueIndex = findSongIndex(state.playbackQueue, song, preferredIndex);
}

// ---- 文件夹管理 ----
async function addFolder() {
  try {
    const invoke = getInvoke();
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
    syncDisplayedSongs();
  } catch (err) {
    console.error('添加文件夹失败:', err);
  }
}

function removeFolder(index) {
  state.folders.splice(index, 1);
  if (state.activeFolder === index) state.activeFolder = null;
  else if (state.activeFolder !== null && state.activeFolder > index) state.activeFolder--;
  syncDisplayedSongs();
}

function selectFolder(index) {
  state.activeFolder = state.activeFolder === index ? null : index;
  syncDisplayedSongs();
}

// ---- 播放控制 ----
async function playSongAt(index) {
  const snapshot = createPlaybackSnapshot(state.displayedSongs, index);
  const song = snapshot.currentSong;
  if (!song) return;

  try {
    const invoke = getInvoke();
    await invoke('play_song', {
      path: song.path,
      index: snapshot.currentQueueIndex,
      playlist: snapshot.playbackQueue,
    });
    state.playbackQueue = snapshot.playbackQueue;
    state.isPlaying = true;
    state.currentSong = song;
    state.currentQueueIndex = snapshot.currentQueueIndex;
    state.currentVisibleIndex = snapshot.currentVisibleIndex;
    state.isCurrentSongVisible = snapshot.isCurrentSongVisible;
    startPolling();
  } catch (err) {
    console.error('播放失败:', err);
  }
}

async function togglePlayPause() {
  if (!state.currentSong) return;
  try {
    const invoke = getInvoke();
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
    const invoke = getInvoke();
    const song = await invoke('play_next');
    if (song) {
      const nextQueueIndex = state.currentQueueIndex === null || state.playbackQueue.length === 0
        ? null
        : (state.currentQueueIndex + 1) % state.playbackQueue.length;
      state.currentSong = song;
      syncQueueIndex(song, nextQueueIndex);
      syncVisiblePlaybackState(song, state.currentQueueIndex);
      state.isPlaying = true;
      startPolling();
    }
  } catch (err) {
    console.error('下一首失败:', err);
  }
}

async function playPrev() {
  try {
    const invoke = getInvoke();
    const song = await invoke('play_prev');
    if (song) {
      const prevQueueIndex = state.currentQueueIndex === null || state.playbackQueue.length === 0
        ? null
        : (state.currentQueueIndex === 0 ? state.playbackQueue.length - 1 : state.currentQueueIndex - 1);
      state.currentSong = song;
      syncQueueIndex(song, prevQueueIndex);
      syncVisiblePlaybackState(song, state.currentQueueIndex);
      state.isPlaying = true;
      startPolling();
    }
  } catch (err) {
    console.error('上一首失败:', err);
  }
}

async function seekTo(pos) {
  try {
    const invoke = getInvoke();
    await invoke('seek_to', { position: pos });
  } catch (err) {
    console.error('跳转失败:', err);
  }
}

async function setVolume(vol) {
  state.volume = vol;
  try {
    const invoke = getInvoke();
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
    const invoke = getInvoke();
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
    get playbackQueue() { return state.playbackQueue; },
    get isPlaying() { return state.isPlaying; },
    get currentSong() { return state.currentSong; },
    get currentQueueIndex() { return state.currentQueueIndex; },
    get currentVisibleIndex() { return state.currentVisibleIndex; },
    get isCurrentSongVisible() { return state.isCurrentSongVisible; },
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
