# MusicBox 🎵

一款基于 SwiftUI 的原生 macOS & iOS 聚合音乐播放器，灵感来源于 [洛雪音乐助手 (lx-music-desktop)](https://github.com/lyswhut/lx-music-desktop)。

> **⚠️ 声明：** 本项目不内置任何音源，不提供任何音乐资源。用户需自行通过订阅地址添加第三方音源脚本。

---

## ✨ 特性

- 🍎 **原生体验** — 纯 Swift + SwiftUI 开发，macOS 和 iOS 双平台
- 🔌 **音源脚本兼容** — 通过 [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) 引擎加载运行音源脚本，兼容 [洛雪音乐助手自定义音源](https://github.com/lyswhut/lx-music-desktop) 格式
- 🔍 **聚合搜索** — 支持多平台搜索和平台筛选
- 🎧 **后台播放** — 基于 AVFoundation，支持后台播放和系统控制中心 / 锁屏控制
- 📋 **歌单管理** — SwiftData 持久化存储，支持创建、编辑、删除歌单
- 📡 **订阅式音源** — 通过 URL 订阅音源脚本，支持一键更新

## 📸 截图

> 🚧 开发中，截图稍后补充

## 🏗 技术栈

| 技术 | 用途 |
|------|------|
| [SwiftUI](https://developer.apple.com/xcode/swiftui/) | 跨平台 UI 框架 |
| [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) | 执行音源 JS 脚本 |
| [AVFoundation](https://developer.apple.com/av-foundation/) | 音频播放引擎 |
| [SwiftData](https://developer.apple.com/xcode/swiftdata/) | 本地数据持久化 |
| [MediaPlayer](https://developer.apple.com/documentation/mediaplayer) | 系统控制中心 / 锁屏控制 |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 项目文件生成 |

## 📂 项目结构

```
MusicBox/
├── project.yml              # XcodeGen 配置
└── Shared/
    ├── App/
    │   └── MusicBoxApp.swift       # App 入口
    ├── Models/
    │   ├── Song.swift               # 歌曲 & 平台枚举
    │   ├── Playlist.swift           # 歌单 (SwiftData)
    │   └── MusicSource.swift        # 音源配置 & 存储
    ├── Services/
    │   ├── MusicSourceEngine.swift  # ⭐ JSCore 音源引擎
    │   └── AudioPlayerService.swift # AVPlayer 播放器
    ├── ViewModels/
    │   ├── SearchViewModel.swift
    │   ├── PlayerViewModel.swift
    │   ├── PlaylistViewModel.swift
    │   └── SettingsViewModel.swift
    └── Views/
        ├── ContentView.swift       # 主布局 (macOS三栏/iOS Tab)
        ├── Search/SearchView.swift
        ├── Player/PlayerView.swift
        ├── Playlist/PlaylistView.swift
        ├── Settings/SettingsView.swift
        └── Components/Extensions.swift
```

## 🚀 快速开始

### 环境要求

- macOS 14.0+ / iOS 17.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（可选，项目已包含 `.xcodeproj`）

### 构建运行

```bash
# 克隆项目
git clone https://github.com/ion-lgb/MusicBox.git
cd MusicBox

# 如需重新生成项目（可选）
brew install xcodegen
xcodegen generate

# 打开项目
open MusicBox.xcodeproj
```

在 Xcode 中选择 `MusicBox_macOS` scheme，点击 ▶️ 运行。

### 使用方法

1. 运行 App → 进入 **设置**
2. 输入音源订阅地址 → 点击 **添加**
3. 返回 **搜索** 页 → 搜索歌曲 → 点击播放

## 🙏 致谢

- [洛雪音乐助手 (lx-music-desktop)](https://github.com/lyswhut/lx-music-desktop) — 本项目的灵感来源和音源脚本格式参考
- [洛雪音乐移动版 (lx-music-mobile)](https://github.com/lyswhut/lx-music-mobile) — 移动端参考

## 📄 开源协议

本项目基于 [Apache License 2.0](LICENSE) 协议开源，与上游项目 [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop) 保持一致。
