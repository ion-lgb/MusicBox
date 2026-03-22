# 🎵 Ion Music Box

一款基于 **Tauri v2 + Vue 3 + Naive UI + Rust** 的桌面端音乐播放器，SPlayer 风格暗色主题。

## 技术栈

| 层 | 技术 | 说明 |
|----|------|------|
| 前端框架 | Vue 3 (Composition API) | 组件化 UI |
| UI 库 | Naive UI | SPlayer 同款，暗色主题，tree-shake |
| 打包器 | Vite 8 | 极速 HMR |
| 桌面框架 | Tauri v2 | 轻量级 WebView 容器 |
| 后端语言 | Rust | 音频解码、文件扫描、HTTP 代理 |
| 音频引擎 | rodio (patched) | 支持 MP3/FLAC/WAV/OGG + Seek |

## 项目结构

```
ion-music-box/
├── index.html                  # Vite 入口
├── vite.config.js              # Vite 配置
├── package.json
├── src/                        # 前端源码
│   ├── main.js                 # Vue 入口
│   ├── App.vue                 # 根组件（Naive UI 暗色主题）
│   ├── style.css               # 全局样式（SPlayer 设计令牌）
│   ├── components/
│   │   ├── Titlebar.vue        # 自定义标题栏 + 搜索框
│   │   ├── Sidebar.vue         # 侧边栏（文件夹 + 音源）
│   │   ├── SongList.vue        # 歌曲列表
│   │   ├── PlayerBar.vue       # 底部播放栏（NSlider 进度条 + 音量）
│   │   └── ImportModal.vue     # 音源脚本导入弹窗（NModal）
│   ├── composables/
│   │   └── usePlayer.js        # 全局播放状态 + Tauri invoke 封装
│   └── utils/
│       └── lx-sandbox.js       # LX Music 自定义源脚本兼容层
├── src-tauri/                  # Rust 后端
│   ├── src/lib.rs              # Tauri commands（扫描/播放/暂停/跳转/音量/网络播放/fetch_text）
│   ├── Cargo.toml
│   ├── rodio-patched/          # 修补版 rodio（支持 Seek + 状态轮询）
│   └── capabilities/           # Tauri 权限配置
└── src-old/                    # 迁移前的原生 HTML/JS（备份）
```

## 已实现功能

### 阶段一：本地音乐播放
- ✅ 本地文件夹扫描（递归扫描 mp3/flac/wav/ogg）
- ✅ 歌曲元数据读取（标题、艺术家、专辑、时长）
- ✅ 音频播放/暂停/恢复/停止
- ✅ 上一首 / 下一首
- ✅ 进度条拖拽跳转 + 实时时间显示
- ✅ 音量滑块控制 + 图标状态
- ✅ 键盘快捷键（Space 播放暂停, Ctrl+← →  切歌）
- ✅ 自动下一首

### 阶段二：SPlayer 风格 UI
- ✅ 自定义无边框标题栏（最小化/最大化/关闭）
- ✅ SPlayer 暗色主题（glassmorphism 风格）
- ✅ 侧边栏文件夹管理
- ✅ 歌曲列表（序号/标题/艺术家/专辑/时长）

### 阶段三：网络音源插件
- ✅ LX Music 自定义源脚本兼容层（`globalThis.lx` API 模拟）
- ✅ 脚本导入（本地 .js 文件 + 远程 URL 下载）
- ✅ 远程链接通过 Rust `fetch_text` 绕过 CORS（支持带 key 的付费链接）
- ✅ 脚本持久化（localStorage，下次启动自动加载）
- ✅ Tauri HTTP 插件（前端 `fetch` 绕过 CORS）
- ✅ `play_url` 命令（Rust 端下载音频 → 内存播放）

### 阶段四：Vue 3 + Naive UI 迁移
- ✅ Vite 8 打包器集成
- ✅ Vue 3 Composition API 组件化重构
- ✅ Naive UI 组件替换（NSlider, NModal, NInput, NButton, NDivider）
- ✅ 全局状态 composable（usePlayer.js）
- ✅ 全本地化（无外部字体/CSS 链接，使用系统字体栈）

## 未完成功能

- ❌ **在线搜索**：LX 自定义源脚本仅提供 `musicUrl/lyric/pic` 获取，需额外搜索 API
- ❌ **歌词显示**：已有 `getLyric` 接口，UI 未实现
- ❌ **封面图片**：已有 `getPic` 接口，UI 未实现
- ❌ **播放模式**：列表循环 / 单曲循环 / 随机播放
- ❌ **系统托盘**：最小化到托盘 + 媒体快捷键
- ❌ **歌单管理**：收藏、创建歌单
- ❌ **音频可视化**：频谱/波形效果
- ❌ **多平台构建**：当前仅 Windows，macOS/Linux 待测试

## 基于 / 参考

- [Tauri v2](https://v2.tauri.app/) — 桌面应用框架
- [SPlayer](https://github.com/imsyy/SPlayer) — UI 风格参考
- [LX Music Desktop](https://github.com/lyswhut/lx-music-desktop) — 自定义音源脚本 API 参考
- [rodio](https://github.com/RustAudio/rodio) — Rust 音频播放库（项目内含修补版）
- [Naive UI](https://www.naiveui.com/) — Vue 3 UI 组件库

## 开发

```bash
# 安装依赖
npm install

# 开发模式（Vite + Tauri 同时启动）
npm run tauri dev

# 生产构建
npm run tauri build
```

> **前置要求**：Rust toolchain、Node.js 18+、Windows 系统

## 许可证

[The Unlicense](LICENSE) — 公共领域，任意使用，无需署名，可商用。
