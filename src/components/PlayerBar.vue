<template>
  <footer id="player-bar">
    <!-- 进度条 -->
    <div class="progress-wrapper">
      <NSlider
        :value="player.state.position"
        :max="player.state.duration || 1"
        :step="0.1"
        :tooltip="false"
        :format-tooltip="formatTime"
        @update:value="onProgressChange"
        @mousedown="player.state.isDraggingProgress = true"
        @mouseup="onProgressEnd"
      />
    </div>

    <!-- 歌曲信息 -->
    <div class="player-info" @click="player.state.showFullPlayer = true" style="cursor: pointer">
      <div class="player-cover">
        <img v-if="player.state.currentCover" :src="player.state.currentCover" alt="cover" class="player-cover-img" />
        <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="28" height="28">
          <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
        </svg>
      </div>
      <div class="player-text">
        <span class="player-title">{{ player.state.currentSong?.title || '未在播放' }}</span>
        <span class="player-artist">{{ player.state.currentSong?.artist || '—' }}</span>
      </div>
    </div>

    <!-- 控制按钮 -->
    <div class="player-center">
      <button class="ctrl-btn" @click="player.playPrev" title="上一首">
        <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>
      </button>
      <button class="ctrl-btn ctrl-btn--play" @click="player.togglePlayPause" :title="player.state.isPlaying ? '暂停' : '播放'">
        <svg v-if="!player.state.isPlaying" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        <svg v-else viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
      </button>
      <button class="ctrl-btn" @click="player.playNext" title="下一首">
        <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>
      </button>
    </div>

    <!-- 右侧：时间 + 音量 -->
    <div class="player-right">
      <span class="player-time">{{ formatTime(player.state.position) }} / {{ formatTime(player.state.duration) }}</span>
      <NSlider
        :value="player.state.volume"
        :min="0"
        :max="1"
        :step="0.01"
        :tooltip="false"
        style="width: 90px"
        @update:value="player.setVolume"
      />
    </div>
  </footer>
</template>

<script setup>
import { NSlider } from 'naive-ui';
import { usePlayer } from '../composables/usePlayer.js';
const player = usePlayer();

function formatTime(s) {
  if (!s || s <= 0) return '0:00';
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, '0')}`;
}

function onProgressChange(val) {
  player.state.position = val;
}

function onProgressEnd() {
  player.state.isDraggingProgress = false;
  player.seekTo(player.state.position);
}
</script>

<style scoped>
#player-bar {
  position: fixed; bottom: 0; left: 0; right: 0;
  height: var(--player-h);
  background: var(--surface-container-hex);
  border-top: 1px solid rgba(var(--primary), 0.06);
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  padding: 0 16px;
  z-index: 100;
}
.progress-wrapper {
  position: absolute; top: -4px; left: 0; right: 0;
  padding: 0 0;
}
.progress-wrapper :deep(.n-slider) { --n-rail-height: 3px; }
.progress-wrapper :deep(.n-slider:hover) { --n-rail-height: 5px; }
.progress-wrapper :deep(.n-slider-handle) {
  width: 12px !important; height: 12px !important;
  opacity: 0; transition: opacity 0.2s;
}
.progress-wrapper:hover :deep(.n-slider-handle) { opacity: 1; }

.player-info {
  display: flex; align-items: center; gap: 12px;
}
.player-cover {
  width: 56px; height: 56px; border-radius: 8px;
  background: rgba(var(--primary), 0.08);
  display: flex; align-items: center; justify-content: center;
  color: var(--text-color-tertiary); flex-shrink: 0;
  overflow: hidden;
}
.player-cover-img {
  width: 100%; height: 100%; object-fit: cover;
}
.player-text { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.player-title {
  font-size: 14px; font-weight: 500; color: var(--text-color);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.player-artist { font-size: 12px; color: var(--text-color-secondary); }

.player-center { display: flex; align-items: center; gap: 4px; }
.ctrl-btn {
  width: 38px; height: 38px; border: none; background: transparent;
  color: var(--text-color-secondary); cursor: pointer; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s var(--bezier);
}
.ctrl-btn:hover { background: rgba(var(--primary), 0.08); color: var(--text-color); }
.ctrl-btn svg { width: 20px; height: 20px; }
.ctrl-btn--play {
  width: 44px; height: 44px;
  background: var(--primary-hex); color: #fff; margin: 0 8px;
}
.ctrl-btn--play:hover { filter: brightness(1.15); background: var(--primary-hex); color: #fff; }
.ctrl-btn--play svg { width: 22px; height: 22px; }

.player-right {
  display: flex; align-items: center; justify-content: flex-end; gap: 12px;
}
.player-time {
  font-size: 12px; color: var(--primary-hex); opacity: 0.8;
  font-variant-numeric: tabular-nums; white-space: nowrap;
}
</style>
