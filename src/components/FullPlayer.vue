<template>
  <Teleport to="body">
    <Transition name="slide-up">
      <div v-if="player.state.showFullPlayer" class="full-player" @click.self="close">
        <!-- 模糊背景 -->
        <div class="fp-bg">
          <img v-if="player.state.currentCover" :src="player.state.currentCover" alt="" class="fp-bg-img" />
        </div>

        <!-- 顶部关闭按钮 -->
        <button class="fp-close" @click="close" title="收起">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24">
            <polyline points="6 9 12 15 18 9"/>
          </svg>
        </button>

        <!-- 主内容区 -->
        <div class="fp-content">
          <!-- 左侧：封面 + 歌曲信息 -->
          <div class="fp-left">
            <div class="fp-cover-wrap">
              <div :class="['fp-disc', { spinning: player.state.isPlaying }]">
                <img
                  v-if="player.state.currentCover"
                  :src="player.state.currentCover"
                  alt="cover"
                  class="fp-cover-img"
                />
                <div v-else class="fp-cover-placeholder">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2" width="64" height="64">
                    <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
                  </svg>
                </div>
              </div>
            </div>
            <div class="fp-song-info">
              <h2 class="fp-title">{{ player.state.currentSong?.title || '未在播放' }}</h2>
              <p class="fp-artist">{{ player.state.currentSong?.artist || '—' }}</p>
              <p v-if="player.state.currentSong?.album" class="fp-album">{{ player.state.currentSong.album }}</p>
            </div>
          </div>

          <!-- 右侧：歌词 -->
          <div class="fp-right" ref="lyricContainerRef">
            <div v-if="player.state.parsedLyric.length" class="fp-lyrics">
              <p
                v-for="(line, idx) in player.state.parsedLyric"
                :key="idx"
                :ref="el => { if (idx === currentLyricIndex) activeLyricEl = el; }"
                :class="['fp-lyric-line', { active: idx === currentLyricIndex }]"
              >{{ line.text }}</p>
            </div>
            <div v-else class="fp-no-lyric">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48" opacity="0.3">
                <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
              </svg>
              <span>暂无歌词</span>
            </div>
          </div>
        </div>

        <!-- 底部控制栏 -->
        <div class="fp-controls">
          <div class="fp-progress">
            <span class="fp-time">{{ formatTime(player.state.position) }}</span>
            <NSlider
              :value="player.state.position"
              :max="player.state.duration || 1"
              :step="0.1"
              :tooltip="false"
              @update:value="onProgressChange"
              @mousedown="player.state.isDraggingProgress = true"
              @mouseup="onProgressEnd"
            />
            <span class="fp-time">{{ formatTime(player.state.duration) }}</span>
          </div>
          <div class="fp-btns">
            <button class="fp-btn" @click="player.playPrev" title="上一首">
              <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>
            </button>
            <button class="fp-btn fp-btn--play" @click="player.togglePlayPause">
              <svg v-if="!player.state.isPlaying" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>
              <svg v-else viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
            </button>
            <button class="fp-btn" @click="player.playNext" title="下一首">
              <svg viewBox="0 0 24 24" fill="currentColor" width="22" height="22"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>
            </button>
          </div>
          <div class="fp-volume">
            <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16" opacity="0.6">
              <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/>
            </svg>
            <NSlider
              :value="player.state.volume"
              :min="0" :max="1" :step="0.01"
              :tooltip="false"
              style="width: 100px"
              @update:value="player.setVolume"
            />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { ref, watch, nextTick, computed } from 'vue';
import { NSlider } from 'naive-ui';
import { usePlayer } from '../composables/usePlayer.js';

const player = usePlayer();
const lyricContainerRef = ref(null);
const activeLyricEl = ref(null);

function close() {
  player.state.showFullPlayer = false;
}

// 当前歌词行索引
const currentLyricIndex = computed(() => {
  const lyrics = player.state.parsedLyric;
  if (!lyrics.length) return -1;
  const pos = player.state.position;
  let idx = 0;
  for (let i = 0; i < lyrics.length; i++) {
    if (lyrics[i].time <= pos) idx = i;
    else break;
  }
  return idx;
});

// 歌词自动滚动
watch(currentLyricIndex, async () => {
  await nextTick();
  if (activeLyricEl.value && lyricContainerRef.value) {
    activeLyricEl.value.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
});

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
.full-player {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  z-index: 200;
  display: flex; flex-direction: column;
  color: #fff;
  overflow: hidden;
}

/* 背景 */
.fp-bg {
  position: absolute; inset: -40px;
  z-index: 0;
  background: #0a0a0e;
}
.fp-bg-img {
  width: 100%; height: 100%;
  object-fit: cover;
  filter: blur(60px) brightness(0.35) saturate(1.4);
  transform: scale(1.2);
}

/* 关闭按钮 */
.fp-close {
  position: absolute; top: 16px; left: 50%; transform: translateX(-50%);
  z-index: 10;
  background: rgba(255,255,255,0.08); border: none; color: rgba(255,255,255,0.7);
  width: 40px; height: 40px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all 0.2s;
  backdrop-filter: blur(8px);
}
.fp-close:hover { background: rgba(255,255,255,0.15); color: #fff; }

/* 主内容 */
.fp-content {
  flex: 1; display: flex; align-items: center;
  padding: 64px 48px 0;
  z-index: 1;
  gap: 48px;
  overflow: hidden;
}

/* 左侧 */
.fp-left {
  flex: 0 0 45%; display: flex; flex-direction: column;
  align-items: center; gap: 24px;
}
.fp-cover-wrap {
  width: 320px; height: 320px;
  border-radius: 50%;
  background: rgba(255,255,255,0.05);
  padding: 16px;
  box-shadow: 0 0 60px rgba(0,0,0,0.5);
}
.fp-disc {
  width: 100%; height: 100%;
  border-radius: 50%;
  overflow: hidden;
  background: linear-gradient(135deg, #1a1a2e, #16161d);
  display: flex; align-items: center; justify-content: center;
}
.fp-disc.spinning {
  animation: disc-spin 20s linear infinite;
}
@keyframes disc-spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
.fp-cover-img {
  width: 100%; height: 100%;
  object-fit: cover; border-radius: 50%;
}
.fp-cover-placeholder {
  color: rgba(255,255,255,0.15);
}
.fp-song-info {
  text-align: center;
}
.fp-title {
  font-size: 22px; font-weight: 600;
  margin: 0 0 6px;
  text-shadow: 0 2px 8px rgba(0,0,0,0.5);
}
.fp-artist {
  font-size: 14px; opacity: 0.7; margin: 0 0 4px;
}
.fp-album {
  font-size: 12px; opacity: 0.5; margin: 0;
}

/* 右侧歌词 */
.fp-right {
  flex: 1; overflow-y: auto;
  max-height: 100%;
  padding: 40px 0;
  mask-image: linear-gradient(transparent, #000 15%, #000 85%, transparent);
  -webkit-mask-image: linear-gradient(transparent, #000 15%, #000 85%, transparent);
}
.fp-right::-webkit-scrollbar { width: 0; }
.fp-lyrics {
  display: flex; flex-direction: column; gap: 16px;
  padding: 120px 0;
}
.fp-lyric-line {
  font-size: 18px; line-height: 1.6;
  color: rgba(255,255,255,0.35);
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: default;
  padding: 4px 0;
}
.fp-lyric-line.active {
  color: #fff;
  font-size: 22px;
  font-weight: 600;
  text-shadow: 0 0 20px rgba(var(--primary), 0.4);
}
.fp-no-lyric {
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  height: 100%; gap: 16px;
  color: rgba(255,255,255,0.3); font-size: 15px;
}

/* 控制栏 */
.fp-controls {
  z-index: 1;
  display: flex; flex-direction: column;
  align-items: center; gap: 8px;
  padding: 0 48px 32px;
}
.fp-progress {
  display: flex; align-items: center; gap: 12px;
  width: 100%; max-width: 680px;
}
.fp-progress :deep(.n-slider) { flex: 1; }
.fp-time {
  font-size: 12px; opacity: 0.6;
  font-variant-numeric: tabular-nums;
  min-width: 36px; text-align: center;
}
.fp-btns {
  display: flex; align-items: center; gap: 12px;
}
.fp-btn {
  width: 44px; height: 44px; border: none;
  background: rgba(255,255,255,0.08); color: rgba(255,255,255,0.8);
  border-radius: 50%; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s; backdrop-filter: blur(4px);
}
.fp-btn:hover { background: rgba(255,255,255,0.15); color: #fff; }
.fp-btn svg { width: 22px; height: 22px; }
.fp-btn--play {
  width: 56px; height: 56px;
  background: var(--primary-hex, rgb(51, 94, 234)); color: #fff;
}
.fp-btn--play:hover { filter: brightness(1.15); background: var(--primary-hex, rgb(51, 94, 234)); }
.fp-btn--play svg { width: 26px; height: 26px; }

.fp-volume {
  display: flex; align-items: center; gap: 8px;
  color: rgba(255,255,255,0.6);
}

/* 动画 */
.slide-up-enter-active,
.slide-up-leave-active {
  transition: transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.slide-up-enter-from,
.slide-up-leave-to {
  transform: translateY(100%);
}
</style>
