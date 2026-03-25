/**
 * Shared utilities for the music player.
 */

/**
 * Format seconds into m:ss string.
 * @param {number} s - Duration in seconds
 */
export function formatTime(s) {
  if (!s || s <= 0) return '0:00';
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${m}:${sec.toString().padStart(2, '0')}`;
}

/**
 * Parse LRC lyric string into sorted { time, text } entries.
 * @param {string} lrcString
 * @returns {{ time: number, text: string }[]}
 */
export function parseLrc(lrcString) {
  if (!lrcString) return [];
  const result = [];
  const lines = lrcString.split('\n');
  const timeReg = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]/g;
  for (const line of lines) {
    const times = [];
    let match;
    while ((match = timeReg.exec(line)) !== null) {
      const min = parseInt(match[1], 10);
      const sec = parseInt(match[2], 10);
      const ms = match[3] ? parseInt(match[3].padEnd(3, '0'), 10) : 0;
      times.push(min * 60 + sec + ms / 1000);
    }
    const text = line.replace(/\[\d{2}:\d{2}(?:\.\d{2,3})?\]/g, '').trim();
    if (text) {
      for (const time of times) {
        result.push({ time, text });
      }
    }
  }
  result.sort((a, b) => a.time - b.time);
  return result;
}
