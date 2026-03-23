<template>
  <!-- 搜索模式 -->
  <div v-if="isSearchMode" class="song-list-container">
    <div class="search-header">
      <span class="search-label">搜索结果 ({{ searchResults.length }})</span>
      <button class="btn-exit-search" @click="exitHandler">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
        返回本地
      </button>
    </div>
    <div v-if="searchLoading" class="empty-state">
      <div class="search-spinner"></div>
      <p>搜索中...</p>
    </div>
    <div v-else-if="searchResults.length === 0" class="empty-state">
      <p>暂无搜索结果</p>
    </div>
    <div v-else class="search-grid">
      <div class="song-list-header">
        <div class="col-play"></div>
        <div class="col-index">#</div>
        <div class="col-title">歌曲</div>
        <div class="col-artist">歌手</div>
        <div class="col-album">专辑</div>
        <div class="col-duration">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
            <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
          </svg>
        </div>
      </div>
      <div class="song-list">
        <div
          v-for="(song, i) in searchResults"
          :key="song.songmid || song.hash || i"
          class="song-row"
        >
          <div class="col-play">
            <button class="btn-play-song" @click="playHandler(song, i, searchResults)" title="播放">
              ▶
            </button>
          </div>
          <div class="col-index">{{ i + 1 }}</div>
          <div class="col-title">{{ song.name || '—' }}</div>
          <div class="col-artist">{{ song.singer || '—' }}</div>
          <div class="col-album">{{ song.albumName || song.album || '—' }}</div>
          <div class="col-duration">{{ formatDuration(song.interval) }}</div>
        </div>
      </div>
    </div>
  </div>
  <!-- 本地模式 -->
  <div v-else-if="player.state.displayedSongs.length === 0" class="empty-state">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="64" height="64">
      <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
    </svg>
    <h2>开始探索你的音乐</h2>
    <p>点击左侧「添加文件夹」导入你的音乐库</p>
  </div>
  <div v-else class="song-list-container">
    <div v-if="player.state.currentSong && !player.state.isCurrentSongVisible" class="queue-banner">
      <strong>当前播放未出现在此筛选结果中。</strong>
      <span>
        正在播放《{{ player.state.currentSong.title || player.state.currentSong.file_name }}》，上一首/下一首仍会按开始播放时的队列继续。
      </span>
    </div>
    <div class="song-list-header">
      <div class="col-index">#</div>
      <div class="col-title">标题</div>
      <div class="col-artist">艺术家</div>
      <div class="col-album">专辑</div>
      <div class="col-duration">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
      </div>
    </div>
    <div class="song-list">
      <div
        v-for="(song, i) in player.state.displayedSongs"
        :key="song.path"
        class="song-row"
        :class="{ playing: player.state.currentSong?.path === song.path }"
        @click="onLocalRowClick(i)"
      >
        <div class="col-index">
          <span v-if="player.state.currentSong?.path === song.path" class="playing-icon">♫</span>
          <span v-else>{{ i + 1 }}</span>
        </div>
        <div class="col-title">{{ song.title || song.file_name }}</div>
        <div class="col-artist">{{ song.artist || '—' }}</div>
        <div class="col-album">{{ song.album || '—' }}</div>
        <div class="col-duration">{{ formatDuration(song.duration) }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { usePlayer } from '../composables/usePlayer.js';
const player = usePlayer();

const props = defineProps({
  searchResults: { type: Array, default: () => [] },
  isSearchMode: { type: Boolean, default: false },
  searchLoading: { type: Boolean, default: false },
  playHandler: { type: Function, default: null },
  exitHandler: { type: Function, default: null },
});

// 本地歌曲双击模拟
let lastClickTime = 0;
let lastClickIndex = -1;
function onLocalRowClick(index) {
  const now = Date.now();
  if (lastClickIndex === index && (now - lastClickTime) < 400) {
    player.playSongAt(index);
    lastClickTime = 0;
    lastClickIndex = -1;
  } else {
    lastClickTime = now;
    lastClickIndex = index;
  }
}

function formatDuration(s) {
  if (!s || s <= 0) return '0:00';
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, '0')}`;
}
</script>

<style scoped>
.empty-state {
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  height: 100%; color: var(--text-color-tertiary);
  gap: 12px;
}
.empty-state h2 { font-size: 18px; font-weight: 500; color: var(--text-color-secondary); }
.empty-state p { font-size: 13px; }

.search-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 0 12px;
}
.search-label {
  font-size: 14px; font-weight: 600; color: var(--text-color);
}
.btn-exit-search {
  display: flex; align-items: center; gap: 4px;
  padding: 6px 12px; border: none; border-radius: 8px;
  background: rgba(var(--primary), 0.08); color: var(--text-color-secondary);
  font-family: var(--font); font-size: 12px; cursor: pointer;
  transition: all 0.2s var(--bezier);
}
.btn-exit-search:hover { background: rgba(var(--primary), 0.15); color: var(--text-color); }
.search-spinner {
  width: 32px; height: 32px;
  border: 3px solid rgba(var(--primary), 0.15);
  border-top-color: var(--primary-hex);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.song-list-container { padding: 4px 16px 0; }
.queue-banner {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin: 4px 0 12px;
  padding: 10px 12px;
  border-radius: 10px;
  background: rgba(var(--primary), 0.08);
  color: var(--text-color-secondary);
  font-size: 12px;
}
.song-list-header, .song-row {
  display: grid;
  grid-template-columns: 40px 2fr 1fr 1fr 60px;
  align-items: center; gap: 8px;
  padding: 0 12px;
}
/* 搜索模式多一个播放按钮列 */
.search-grid .song-list-header,
.search-grid .song-row {
  grid-template-columns: 32px 40px 2fr 1fr 1fr 60px;
}
.song-list-header {
  font-size: 11px; font-weight: 600; color: var(--text-color-tertiary);
  text-transform: uppercase; letter-spacing: 0.5px;
  padding-bottom: 8px; border-bottom: 1px solid rgba(var(--primary), 0.06);
}
.song-row {
  font-size: 13px; color: var(--text-color-secondary);
  padding: 10px 12px; border-radius: 10px;
  cursor: pointer; transition: all 0.15s var(--bezier);
}
.song-row:hover { background: rgba(var(--primary), 0.05); color: var(--text-color); }
.song-row.playing {
  background: rgba(var(--primary), 0.1);
  color: var(--primary-hex); font-weight: 500;
}
.playing-icon { color: var(--primary-hex); font-size: 14px; }
.col-play { display: flex; align-items: center; justify-content: center; }
.btn-play-song {
  width: 26px; height: 26px; border: none; border-radius: 50%;
  background: var(--primary-hex); color: #fff;
  font-size: 11px; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s var(--bezier);
  opacity: 0.7;
}
.song-row:hover .btn-play-song { opacity: 1; transform: scale(1.1); }
.btn-play-song:hover { opacity: 1; transform: scale(1.15); }
.col-index { text-align: center; font-variant-numeric: tabular-nums; }
.col-title { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-artist, .col-album {
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  font-size: 12px;
}
.col-duration { text-align: right; font-size: 12px; font-variant-numeric: tabular-nums; }
</style>
