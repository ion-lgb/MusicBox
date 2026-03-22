# 贡献指南

感谢你对 Ion Music Box 的关注！欢迎任何形式的贡献。

## 如何贡献

### 报告 Bug
1. 在 [Issues](https://github.com/ion-lgb/MusicBox/issues) 中搜索是否已有相同问题
2. 新建 Issue，描述：复现步骤、预期行为、实际行为、系统环境

### 功能建议
1. 在 Issues 中新建，标题加 `[Feature]` 前缀
2. 说明使用场景和期望效果

### 提交代码
1. Fork 本仓库
2. 基于 `main` 创建分支：`git checkout -b feat/你的功能`
3. 提交更改：`git commit -m "feat: 描述"`
4. 推送并发起 Pull Request

## 开发环境

```bash
# 前置要求
# - Node.js 18+
# - Rust toolchain (rustup)
# - Windows 系统

# 安装依赖
npm install

# 启动开发
npm run tauri dev
```

## 项目结构

- `src/` — Vue 3 前端（组件、composables、工具）
- `src-tauri/` — Rust 后端（Tauri commands、音频引擎）
- `src-tauri/rodio-patched/` — 修补版 rodio

## Commit 规范

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

| 前缀 | 用途 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | 修复 Bug |
| `docs:` | 文档更新 |
| `style:` | 样式调整（不影响逻辑） |
| `refactor:` | 重构 |
| `chore:` | 构建/工具变更 |

## 许可证

提交代码即表示你同意将贡献以 [AGPL-3.0](LICENSE) 许可证发布。
