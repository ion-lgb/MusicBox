<template>
  <div v-if="player.state.displayedSongs.length === 0" class="empty-state">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="64" height="64">
      <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
    </svg>
    <h2>开始探索你的音乐</h2>
    <p>点击左侧「添加文件夹」导入你的音乐库</p>
  </div>
  <div v-else class="song-list-container">
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
        :class="{ playing: player.state.currentIndex === i }"
        @dblclick="player.playSongAt(i)"
      >
        <div class="col-index">
          <span v-if="player.state.currentIndex === i" class="playing-icon">♫</span>
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

.song-list-container { padding: 4px 16px 0; }
.song-list-header, .song-row {
  display: grid;
  grid-template-columns: 40px 2fr 1fr 1fr 60px;
  align-items: center; gap: 8px;
  padding: 0 12px;
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
.col-index { text-align: center; font-variant-numeric: tabular-nums; }
.col-title { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-artist, .col-album {
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  font-size: 12px;
}
.col-duration { text-align: right; font-size: 12px; font-variant-numeric: tabular-nums; }
</style>
