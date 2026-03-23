/**
 * musicSdk — 内置多平台音乐搜索 SDK
 * 直接翻译自 lx-music-desktop 的 musicSdk 实现
 * 搜索通过 Rust fetch_text 发请求避免 CORS
 */
import { invoke } from '@tauri-apps/api/core';

// ---- 工具函数 ----
function decodeName(str) {
  if (!str) return '';
  return String(str)
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&#39;/g, "'");
}

function sizeFormate(size) {
  if (!size) return '';
  size = parseInt(size);
  if (size < 1024) return size + 'B';
  if (size < 1048576) return (size / 1024).toFixed(1) + 'KB';
  return (size / 1048576).toFixed(1) + 'MB';
}

function formatSingerName(list, key = 'name') {
  if (!list) return '';
  if (typeof list === 'string') return list;
  return list.map(s => s[key] || s.name || '').filter(Boolean).join('、');
}

// ---- 酷我 (kw) ----
const kw = {
  name: '酷我',
  limit: 30,
  regExps: { mInfo: /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/ },

  async search(keyword, page = 1, limit = 30) {
    const url = `http://search.kuwo.cn/r.s?client=kt&all=${encodeURIComponent(keyword)}&pn=${page - 1}&rn=${limit}&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1`;
    const text = await invoke('fetch_text', { url });
    let data;
    try { data = JSON.parse(text); } catch {
      const m = text.match(/\((.+)\)/s);
      data = m ? JSON.parse(m[1]) : null;
    }
    if (!data?.abslist) return { list: [], allPage: 0, total: 0, limit, source: 'kw' };

    const total = parseInt(data.TOTAL) || 0;
    const list = data.abslist.map(info => {
      const songId = (info.MUSICRID || '').replace('MUSIC_', '');
      const types = [];
      if (info.N_MINFO) {
        for (const part of info.N_MINFO.split(';')) {
          const m = part.match(kw.regExps.mInfo);
          if (m) {
            if (m[2] === '2000') types.push({ type: 'flac', size: m[4] });
            else if (m[2] === '320') types.push({ type: '320k', size: m[4] });
            else if (m[2] === '128') types.push({ type: '128k', size: m[4] });
          }
        }
      }
      const interval = parseInt(info.DURATION);
      return {
        name: decodeName(info.SONGNAME),
        singer: decodeName(info.ARTIST),
        source: 'kw',
        songmid: songId,
        albumName: info.ALBUM ? decodeName(info.ALBUM) : '',
        interval: Number.isNaN(interval) ? 0 : interval,
        types,
      };
    });
    return { list, allPage: Math.ceil(total / limit), total, limit, source: 'kw' };
  },
};

// ---- 酷狗 (kg) ----
const kg = {
  name: '酷狗',
  limit: 30,

  async search(keyword, page = 1, limit = 30) {
    const url = `https://songsearch.kugou.com/song_search_v2?keyword=${encodeURIComponent(keyword)}&page=${page}&pagesize=${limit}&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1`;
    const text = await invoke('fetch_text', { url });
    const body = JSON.parse(text);
    if (!body || body.error_code !== 0) return { list: [], allPage: 0, total: 0, limit, source: 'kg' };

    const rawList = body.data?.lists || [];
    const ids = new Set();
    const list = [];
    for (const item of rawList) {
      const key = `${item.Audioid}_${item.FileHash}`;
      if (ids.has(key)) continue;
      ids.add(key);
      const types = [];
      if (item.FileSize) types.push({ type: '128k', size: sizeFormate(item.FileSize) });
      if (item.HQFileSize) types.push({ type: '320k', size: sizeFormate(item.HQFileSize) });
      if (item.SQFileSize) types.push({ type: 'flac', size: sizeFormate(item.SQFileSize) });
      list.push({
        name: decodeName(item.SongName),
        singer: decodeName(formatSingerName(item.Singers || [], 'name')),
        source: 'kg',
        songmid: item.Audioid,
        hash: item.FileHash,
        albumName: decodeName(item.AlbumName),
        interval: item.Duration || 0,
        types,
      });
      // 子分组
      if (item.Grp) {
        for (const child of item.Grp) {
          const ck = `${child.Audioid}_${child.FileHash}`;
          if (ids.has(ck)) continue;
          ids.add(ck);
          const ctypes = [];
          if (child.FileSize) ctypes.push({ type: '128k', size: sizeFormate(child.FileSize) });
          if (child.HQFileSize) ctypes.push({ type: '320k', size: sizeFormate(child.HQFileSize) });
          if (child.SQFileSize) ctypes.push({ type: 'flac', size: sizeFormate(child.SQFileSize) });
          list.push({
            name: decodeName(child.SongName),
            singer: decodeName(formatSingerName(child.Singers || [], 'name')),
            source: 'kg',
            songmid: child.Audioid,
            hash: child.FileHash,
            albumName: decodeName(child.AlbumName),
            interval: child.Duration || 0,
            types: ctypes,
          });
        }
      }
    }
    const total = body.data?.total || 0;
    return { list, allPage: Math.ceil(total / limit), total, limit, source: 'kg' };
  },
};

// ---- QQ音乐 (tx) ----
const tx = {
  name: 'QQ音乐',
  limit: 30,

  async search(keyword, page = 1, limit = 30) {
    const reqBody = JSON.stringify({
      comm: {
        ct: '11', cv: '14090508', v: '14090508',
        tmeAppID: 'qqmusic',
        os_ver: '12',
      },
      req: {
        module: 'music.search.SearchCgiService',
        method: 'DoSearchForQQMusicMobile',
        param: {
          search_type: 0,
          query: keyword,
          page_num: page,
          num_per_page: limit,
          highlight: 0,
          nqc_flag: 0,
        },
      },
    });
    // 使用 fetch_text_post 如果可用, 否则 fallback 到 fetch_text
    // 当前 fetch_text 只支持 GET，需要用 POST — 先通过 GET 的代理方式尝试
    // QQ 音乐也有 GET 版本接口
    const url = `https://u.y.qq.com/cgi-bin/musicu.fcg?data=${encodeURIComponent(reqBody)}`;
    const text = await invoke('fetch_text', { url });
    const body = JSON.parse(text);

    if (!body || body.code !== 0 || !body.req || body.req.code !== 0) {
      return { list: [], allPage: 0, total: 0, limit, source: 'tx' };
    }

    const data = body.req.data;
    const rawList = data?.body?.item_song || data?.body?.song?.list || [];
    const list = rawList.map(item => {
      const types = [];
      const file = item.file || {};
      if (file.size_128mp3) types.push({ type: '128k', size: sizeFormate(file.size_128mp3) });
      if (file.size_320mp3) types.push({ type: '320k', size: sizeFormate(file.size_320mp3) });
      if (file.size_flac) types.push({ type: 'flac', size: sizeFormate(file.size_flac) });
      return {
        name: item.name + (item.title_extra || ''),
        singer: formatSingerName(item.singer, 'name'),
        source: 'tx',
        songmid: item.mid,
        songId: item.id,
        albumName: item.album?.name || '',
        albumMid: item.album?.mid || '',
        interval: item.interval || 0,
        strMediaMid: file.media_mid || '',
        types,
      };
    }).filter(s => s.songmid);

    const total = data?.meta?.estimate_sum || data?.meta?.sum || 0;
    return { list, allPage: Math.ceil(total / limit), total, limit, source: 'tx' };
  },
};

// ---- 全部源 ----
export const SOURCES = {
  kw: { name: '酷我', id: 'kw' },
  kg: { name: '酷狗', id: 'kg' },
  tx: { name: 'QQ音乐', id: 'tx' },
};

const sdkMap = { kw, kg, tx };

/**
 * 搜索歌曲
 * @param {string} keyword
 * @param {number} page
 * @param {string} source - 搜索源 key
 * @returns {Promise<{list: Array, allPage: number, total: number, limit: number, source: string}>}
 */
export async function searchMusic(keyword, page = 1, source = 'kw') {
  const sdk = sdkMap[source];
  if (!sdk) throw new Error(`不支持的搜索源: ${source}`);
  return sdk.search(keyword, page);
}
