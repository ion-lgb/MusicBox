/**
 * LX Music 自定义源脚本兼容层
 * 模拟 globalThis.lx API，让 LX Music 自定义源脚本能在 Tauri WebView 中运行
 *
 * 安全模型：使用 Proxy + with(this) 白名单沙箱，拦截所有变量查找，
 *          仅允许脚本访问显式白名单中的安全 API。
 *
 * 参考: https://lyswhut.github.io/lx-music-doc/desktop/custom-source
 */

import { fetch as tauriFetch } from '@tauri-apps/plugin-http';

// ============================================================
// 常量
// ============================================================
const EVENT_NAMES = {
  request: 'request',
  inited: 'inited',
};

// ============================================================
// 安全的 console 代理（仅允许日志输出，不暴露真实 console 对象链）
// ============================================================
const _safeConsole = Object.freeze({
  log: (...args) => console.log('[LxScript]', ...args),
  warn: (...args) => console.warn('[LxScript]', ...args),
  error: (...args) => console.error('[LxScript]', ...args),
  info: (...args) => console.info('[LxScript]', ...args),
  debug: (...args) => console.debug('[LxScript]', ...args),
});

// ============================================================
// 安全的 setTimeout/setInterval 包装（限制最大并发定时器数量）
// ============================================================
const _MAX_TIMERS = 64;
const _activeTimers = new Set();

function _safeSetTimeout(fn, delay, ...args) {
  if (_activeTimers.size >= _MAX_TIMERS) {
    console.warn('[LxSandbox] 定时器数量已达上限，忽略新的 setTimeout 调用');
    return -1;
  }
  const id = setTimeout((...a) => {
    _activeTimers.delete(id);
    if (typeof fn === 'function') fn(...a);
  }, delay, ...args);
  _activeTimers.add(id);
  return id;
}

function _safeClearTimeout(id) {
  clearTimeout(id);
  _activeTimers.delete(id);
}

function _safeSetInterval(fn, delay, ...args) {
  if (_activeTimers.size >= _MAX_TIMERS) {
    console.warn('[LxSandbox] 定时器数量已达上限，忽略新的 setInterval 调用');
    return -1;
  }
  const id = setInterval(fn, delay, ...args);
  _activeTimers.add(id);
  return id;
}

function _safeClearInterval(id) {
  clearInterval(id);
  _activeTimers.delete(id);
}

// ============================================================
// 白名单：沙箱内脚本可访问的全局 API
// ============================================================
function _buildWhitelist(lx, sandboxGlobal) {
  return new Map([
    // -- LX 核心 API --
    ['lx', lx],
    // -- 日志 --
    ['console', _safeConsole],
    // -- 定时器 --
    ['setTimeout', _safeSetTimeout],
    ['clearTimeout', _safeClearTimeout],
    ['setInterval', _safeSetInterval],
    ['clearInterval', _safeClearInterval],
    // -- 基本类型 & 工具 --
    ['Promise', Promise],
    ['JSON', JSON],
    ['Math', Math],
    ['Date', Date],
    ['RegExp', RegExp],
    ['Error', Error],
    ['TypeError', TypeError],
    ['RangeError', RangeError],
    ['SyntaxError', SyntaxError],
    ['Map', Map],
    ['Set', Set],
    ['WeakMap', WeakMap],
    ['WeakSet', WeakSet],
    ['Symbol', Symbol],
    ['Object', Object],
    ['Array', Array],
    ['String', String],
    ['Number', Number],
    ['Boolean', Boolean],
    // -- 数值工具 --
    ['parseInt', parseInt],
    ['parseFloat', parseFloat],
    ['isNaN', isNaN],
    ['isFinite', isFinite],
    ['NaN', NaN],
    ['Infinity', Infinity],
    ['undefined', undefined],
    // -- URI 编码 --
    ['encodeURIComponent', encodeURIComponent],
    ['decodeURIComponent', decodeURIComponent],
    ['encodeURI', encodeURI],
    ['decodeURI', decodeURI],
    // -- 二进制 --
    ['Uint8Array', Uint8Array],
    ['Int8Array', Int8Array],
    ['Uint16Array', Uint16Array],
    ['Int16Array', Int16Array],
    ['Uint32Array', Uint32Array],
    ['Int32Array', Int32Array],
    ['Float32Array', Float32Array],
    ['Float64Array', Float64Array],
    ['ArrayBuffer', ArrayBuffer],
    ['DataView', DataView],
    ['TextEncoder', TextEncoder],
    ['TextDecoder', TextDecoder],
    // -- URL --
    ['URL', URL],
    ['URLSearchParams', URLSearchParams],
    // -- 加密（受限） --
    ['crypto', Object.freeze({ getRandomValues: (arr) => globalThis.crypto.getRandomValues(arr) })],
    // -- 压缩/解压 --
    ['CompressionStream', CompressionStream],
    ['DecompressionStream', DecompressionStream],
    // -- 全局自引用（指向沙箱而非真实 window） --
    ['globalThis', sandboxGlobal],
    ['window', sandboxGlobal],
    ['self', sandboxGlobal],
    ['global', sandboxGlobal],
  ]);
}

// ============================================================
// LX Sandbox 类
// ============================================================
class LxSandbox {
  constructor() {
    this._handlers = {};    // 脚本注册的事件处理函数
    this._sources = null;   // 脚本声明的音源信息
    this._scriptMeta = null; // 脚本头部注释元数据
    this._ready = false;
  }

  /**
   * 解析脚本头部注释中的元数据
   * @param {string} scriptContent
   * @returns {{ name, description, version, author, homepage }}
   */
  parseScriptMeta(scriptContent) {
    const meta = {};
    const headerMatch = scriptContent.match(/\/\*\*([\s\S]*?)\*\//);
    if (headerMatch) {
      const header = headerMatch[1];
      const fields = ['name', 'description', 'version', 'author', 'homepage'];
      for (const field of fields) {
        const m = header.match(new RegExp(`@${field}\\s+(.+)`));
        if (m) meta[field] = m[1].trim();
      }
    }
    return meta;
  }

  /**
   * 加载并执行一个 LX 音源脚本
   * @param {string} scriptContent - JS 脚本文本内容
   * @returns {Promise<object>} - sources 对象
   */
  load(scriptContent) {
    return new Promise((resolve, reject) => {
      // 解析元数据
      this._scriptMeta = this.parseScriptMeta(scriptContent);
      this._handlers = {};
      this._sources = null;
      this._ready = false;

      // ---- 构造 globalThis.lx ----
      const self = this;

      // lx.on — 脚本注册事件处理
      const on = (eventName, handler) => {
        self._handlers[eventName] = handler;
      };

      // lx.send — 脚本主动通知应用
      const send = (eventName, data) => {
        if (eventName === EVENT_NAMES.inited) {
          self._sources = data.sources || {};
          self._ready = true;
          console.log('[LxSandbox] 脚本初始化完成:', self._scriptMeta?.name || '未命名', data.sources);
          resolve(self._sources);
        }
      };

      // lx.request — HTTP 请求（通过 Tauri HTTP 插件，绕过 CORS）
      const request = (url, options, callback) => {
        const method = (options?.method || 'GET').toUpperCase();
        const headers = options?.headers || {};
        const body = options?.body || undefined;

        const fetchOpts = { method, headers };
        if (body && method !== 'GET') {
          fetchOpts.body = typeof body === 'string' ? body : JSON.stringify(body);
        }
        if (options?.form) {
          const params = new URLSearchParams(options.form);
          fetchOpts.body = params.toString();
          fetchOpts.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }

        const controller = new AbortController();
        fetchOpts.signal = controller.signal;
        if (options?.timeout) {
          setTimeout(() => controller.abort(), options.timeout * 1000);
        }

        // 使用 ES module 导入的 Tauri fetch（不再依赖 window.__TAURI__）
        tauriFetch(url, fetchOpts)
          .then(async (resp) => {
            const contentType = resp.headers.get('content-type') || '';
            let responseBody;
            if (contentType.includes('json')) {
              responseBody = await resp.json();
            } else {
              responseBody = await resp.text();
            }
            callback(null, { statusCode: resp.status, headers: Object.fromEntries(resp.headers.entries()), body: responseBody }, responseBody);
          })
          .catch((err) => {
            callback(err, null, null);
          });

        // 返回取消函数
        return () => controller.abort();
      };

      // lx.utils — 基础工具方法
      const utils = {
        buffer: {
          from: (data, encoding) => {
            if (typeof data === 'string') {
              return new TextEncoder().encode(data);
            }
            return new Uint8Array(data);
          },
          bufToString: (buffer, encoding) => {
            return new TextDecoder(encoding || 'utf-8').decode(buffer);
          },
        },
        crypto: {
          md5: (str) => {
            return _md5(str);
          },
          aesEncrypt: (buffer, mode, key, iv) => {
            console.warn('[LxSandbox] aesEncrypt 未完整实现');
            return buffer;
          },
          randomBytes: (size) => {
            const arr = new Uint8Array(size);
            globalThis.crypto.getRandomValues(arr);
            return arr;
          },
          rsaEncrypt: (buffer, key) => {
            console.warn('[LxSandbox] rsaEncrypt 未完整实现');
            return buffer;
          },
        },
        zlib: {
          inflate: async (buffer) => {
            const ds = new DecompressionStream('deflate');
            const writer = ds.writable.getWriter();
            writer.write(buffer);
            writer.close();
            const reader = ds.readable.getReader();
            const chunks = [];
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              chunks.push(value);
            }
            const totalLength = chunks.reduce((acc, c) => acc + c.length, 0);
            const result = new Uint8Array(totalLength);
            let offset = 0;
            for (const chunk of chunks) {
              result.set(chunk, offset);
              offset += chunk.length;
            }
            return result;
          },
          deflate: async (buffer) => {
            const cs = new CompressionStream('deflate');
            const writer = cs.writable.getWriter();
            writer.write(buffer);
            writer.close();
            const reader = cs.readable.getReader();
            const chunks = [];
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              chunks.push(value);
            }
            const totalLength = chunks.reduce((acc, c) => acc + c.length, 0);
            const result = new Uint8Array(totalLength);
            let offset = 0;
            for (const chunk of chunks) {
              result.set(chunk, offset);
              offset += chunk.length;
            }
            return result;
          },
        },
      };

      // 构建 lx 对象
      const lx = {
        version: '2.7.0',
        env: 'desktop',
        currentScriptInfo: self._scriptMeta || {},
        EVENT_NAMES,
        on,
        send,
        request,
        utils,
      };

      // ---- 使用 Proxy + with(this) 沙箱执行脚本 ----
      // Proxy.has 返回 true 使所有变量查找经过沙箱
      // Proxy.get 仅返回白名单中的值，阻断 window/document/Function/eval/__TAURI__ 等逃逸路径
      try {
        const whitelist = _buildWhitelist(lx, null); // 先创建，sandboxGlobal 稍后回填
        const scriptVars = Object.create(null); // 脚本中赋值的变量存储在这里

        const sandboxGlobal = new Proxy(Object.create(null), {
          has: () => true,
          get: (_target, prop) => {
            // 脚本自定义变量优先
            if (prop in scriptVars) return scriptVars[prop];
            // 白名单
            if (whitelist.has(prop)) return whitelist.get(prop);
            // 拦截危险全局
            if (prop === 'Function' || prop === 'eval'
                || prop === 'document' || prop === 'top' || prop === 'parent' || prop === 'frames'
                || prop === 'location' || prop === 'navigator' || prop === 'history'
                || prop === '__TAURI__' || prop === '__TAURI_PLUGIN_HTTP__'
                || prop === '__TAURI_INTERNALS__'
                || prop === 'fetch' || prop === 'XMLHttpRequest'
                || prop === 'importScripts' || prop === 'Worker' || prop === 'SharedWorker'
                || prop === 'ServiceWorker') {
              return undefined;
            }
            return undefined;
          },
          set: (_target, prop, value) => {
            scriptVars[prop] = value;
            return true;
          },
          deleteProperty: (_target, prop) => {
            delete scriptVars[prop];
            return true;
          },
        });

        // 回填 sandboxGlobal 自引用
        whitelist.set('globalThis', sandboxGlobal);
        whitelist.set('window', sandboxGlobal);
        whitelist.set('self', sandboxGlobal);
        whitelist.set('global', sandboxGlobal);

        // with(this) 使得脚本中所有变量查找都经过 Proxy
        // new Function 默认 sloppy mode，with 可用
        const wrappedScript = `with(this){${scriptContent}\n}`;
        const fn = new Function(wrappedScript);
        fn.call(sandboxGlobal);
      } catch (err) {
        reject(new Error(`脚本执行错误: ${err.message}`));
      }

      // 超时检测
      setTimeout(() => {
        if (!self._ready) {
          reject(new Error('脚本初始化超时（5秒内未发送 inited 事件）'));
        }
      }, 5000);
    });
  }

  /**
   * 调用脚本获取音乐 URL
   * @param {string} source - 音源 key (如 kw, kg, tx, wy, mg)
   * @param {object} musicInfo - 歌曲信息对象
   * @param {string} quality - 音质 (128k, 320k, flac 等)
   * @returns {Promise<string>} - 歌曲直链 URL
   */
  async getMusicUrl(source, musicInfo, quality) {
    const handler = this._handlers[EVENT_NAMES.request];
    if (!handler) throw new Error('脚本未注册 request 事件处理');
    return handler({
      source,
      action: 'musicUrl',
      info: { type: quality, musicInfo },
    });
  }

  /**
   * 获取歌词
   */
  async getLyric(source, musicInfo) {
    const handler = this._handlers[EVENT_NAMES.request];
    if (!handler) throw new Error('脚本未注册 request 事件处理');
    return handler({
      source,
      action: 'lyric',
      info: { musicInfo },
    });
  }

  /**
   * 获取封面
   */
  async getPic(source, musicInfo) {
    const handler = this._handlers[EVENT_NAMES.request];
    if (!handler) throw new Error('脚本未注册 request 事件处理');
    return handler({
      source,
      action: 'pic',
      info: { musicInfo },
    });
  }

  /** 获取已注册的源信息 */
  get sources() { return this._sources; }
  /** 获取脚本元数据 */
  get meta() { return this._scriptMeta; }
  /** 是否已初始化 */
  get ready() { return this._ready; }
}

// ============================================================
// 简单 MD5 实现 (用于 lx.utils.crypto.md5)
// ============================================================
function _md5(string) {
  function md5cycle(x, k) {
    let a = x[0], b = x[1], c = x[2], d = x[3];
    a = ff(a,b,c,d,k[0],7,-680876936);d = ff(d,a,b,c,k[1],12,-389564586);c = ff(c,d,a,b,k[2],17,606105819);b = ff(b,c,d,a,k[3],22,-1044525330);
    a = ff(a,b,c,d,k[4],7,-176418897);d = ff(d,a,b,c,k[5],12,1200080426);c = ff(c,d,a,b,k[6],17,-1473231341);b = ff(b,c,d,a,k[7],22,-45705983);
    a = ff(a,b,c,d,k[8],7,1770035416);d = ff(d,a,b,c,k[9],12,-1958414417);c = ff(c,d,a,b,k[10],17,-42063);b = ff(b,c,d,a,k[11],22,-1990404162);
    a = ff(a,b,c,d,k[12],7,1804603682);d = ff(d,a,b,c,k[13],12,-40341101);c = ff(c,d,a,b,k[14],17,-1502002290);b = ff(b,c,d,a,k[15],22,1236535329);
    a = gg(a,b,c,d,k[1],5,-165796510);d = gg(d,a,b,c,k[6],9,-1069501632);c = gg(c,d,a,b,k[11],14,643717713);b = gg(b,c,d,a,k[0],20,-373897302);
    a = gg(a,b,c,d,k[5],5,-701558691);d = gg(d,a,b,c,k[10],9,38016083);c = gg(c,d,a,b,k[15],14,-660478335);b = gg(b,c,d,a,k[4],20,-405537848);
    a = gg(a,b,c,d,k[9],5,568446438);d = gg(d,a,b,c,k[14],9,-1019803690);c = gg(c,d,a,b,k[3],14,-187363961);b = gg(b,c,d,a,k[8],20,1163531501);
    a = gg(a,b,c,d,k[13],5,-1444681467);d = gg(d,a,b,c,k[2],9,-51403784);c = gg(c,d,a,b,k[7],14,1735328473);b = gg(b,c,d,a,k[12],20,-1926607734);
    a = hh(a,b,c,d,k[5],4,-378558);d = hh(d,a,b,c,k[8],11,-2022574463);c = hh(c,d,a,b,k[11],16,1839030562);b = hh(b,c,d,a,k[14],23,-35309556);
    a = hh(a,b,c,d,k[1],4,-1530992060);d = hh(d,a,b,c,k[4],11,1272893353);c = hh(c,d,a,b,k[7],16,-155497632);b = hh(b,c,d,a,k[10],23,-1094730640);
    a = hh(a,b,c,d,k[13],4,681279174);d = hh(d,a,b,c,k[0],11,-358537222);c = hh(c,d,a,b,k[3],16,-722521979);b = hh(b,c,d,a,k[6],23,76029189);
    a = hh(a,b,c,d,k[9],4,-640364487);d = hh(d,a,b,c,k[12],11,-421815835);c = hh(c,d,a,b,k[15],16,530742520);b = hh(b,c,d,a,k[2],23,-995338651);
    a = ii(a,b,c,d,k[0],6,-198630844);d = ii(d,a,b,c,k[7],10,1126891415);c = ii(c,d,a,b,k[14],15,-1416354905);b = ii(b,c,d,a,k[5],21,-57434055);
    a = ii(a,b,c,d,k[12],6,1700485571);d = ii(d,a,b,c,k[3],10,-1894986606);c = ii(c,d,a,b,k[10],15,-1051523);b = ii(b,c,d,a,k[1],21,-2054922799);
    a = ii(a,b,c,d,k[8],6,1873313359);d = ii(d,a,b,c,k[15],10,-30611744);c = ii(c,d,a,b,k[6],15,-1560198380);b = ii(b,c,d,a,k[13],21,1309151649);
    a = ii(a,b,c,d,k[4],6,-145523070);d = ii(d,a,b,c,k[11],10,-1120210379);c = ii(c,d,a,b,k[2],15,718787259);b = ii(b,c,d,a,k[9],21,-343485551);
    x[0] = add32(a, x[0]);x[1] = add32(b, x[1]);x[2] = add32(c, x[2]);x[3] = add32(d, x[3]);
  }
  function cmn(q,a,b,x,s,t) { a = add32(add32(a,q),add32(x,t)); return add32((a<<s)|(a>>>(32-s)),b); }
  function ff(a,b,c,d,x,s,t) { return cmn((b&c)|((~b)&d),a,b,x,s,t); }
  function gg(a,b,c,d,x,s,t) { return cmn((b&d)|(c&(~d)),a,b,x,s,t); }
  function hh(a,b,c,d,x,s,t) { return cmn(b^c^d,a,b,x,s,t); }
  function ii(a,b,c,d,x,s,t) { return cmn(c^(b|(~d)),a,b,x,s,t); }
  function md51(s) {
    let n = s.length, state = [1732584193,-271733879,-1732584194,271733878], i;
    for (i=64;i<=n;i+=64) md5cycle(state,md5blk(s.substring(i-64,i)));
    s = s.substring(i-64);
    let tail = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    for (i=0;i<s.length;i++) tail[i>>2] |= s.charCodeAt(i) << ((i%4)<<3);
    tail[i>>2] |= 0x80 << ((i%4)<<3);
    if (i>55) { md5cycle(state,tail); tail = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]; }
    tail[14] = n*8;
    md5cycle(state,tail);
    return state;
  }
  function md5blk(s) {
    let md5blks = [], i;
    for (i=0;i<64;i+=4) md5blks[i>>2] = s.charCodeAt(i)+(s.charCodeAt(i+1)<<8)+(s.charCodeAt(i+2)<<16)+(s.charCodeAt(i+3)<<24);
    return md5blks;
  }
  const hex_chr = '0123456789abcdef'.split('');
  function rhex(n) {
    let s='';
    for (let j=0;j<4;j++) s += hex_chr[(n>>(j*8+4))&0x0F]+hex_chr[(n>>(j*8))&0x0F];
    return s;
  }
  function add32(a,b) { return (a+b)&0xFFFFFFFF; }
  function hex(x) { for (let i=0;i<x.length;i++) x[i]=rhex(x[i]); return x.join(''); }
  return hex(md51(string));
}

// ============================================================
// 导出 (ES Module)
// ============================================================
export { LxSandbox };
