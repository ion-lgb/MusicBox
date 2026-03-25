# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
npm install
npm run tauri dev      # Development mode (Vite + Tauri hot reload)
npm run tauri build    # Production build
```

Requirements: Rust toolchain, Node.js 18+, Windows.

## Architecture

### Frontend (Vue 3 + Naive UI)

- **State hub**: [usePlayer.js](src/composables/usePlayer.js) — single reactive singleton exported as a composable. All player state (folders, playlist, playback position, volume, etc.) lives here. Components access it via `const player = usePlayer()`.
- **Components** use Naive UI components (NSlider, NModal, NInput, NButton). Dark SPlayer-style theme via global CSS.
- **LX Music compatibility**: [lx-sandbox.js](src/utils/lx-sandbox.js) injects a `globalThis.lx` object that mocks the LX Music script API (musicUrl, lyric, pic). Scripts are stored in localStorage and loaded on startup.

### Rust Backend

- **Audio thread pattern**: `spawn_audio_thread()` in [lib.rs](src-tauri/src/lib.rs) owns the `OutputStream` (must stay on one thread). All audio operations are sent via an `mpsc::Channel<AudioCommand>`. This avoids `!Send` issues with rodio's `OutputStream`.
- **Playback**: `Play(path)` for local files, `PlayData(Vec<u8>)` for in-memory audio (used by `play_url`). The `rodio-patched` submodule adds Seek support to the standard rodio crate.
- **Network audio**: `play_url` downloads audio bytes via `reqwest`, passes them to the audio thread as `PlayData`. `fetch_text` is a separate command for fetching LX script content.
- **Metadata**: `get_song_meta` extracts embedded album art (base64 data URI) and lyrics using the `lofty` crate.

### Tauri Commands (Rust → JS)

| Command | Purpose |
|---|---|
| `pick_folder` | Native folder picker dialog |
| `scan_music_dir` | Recursive scan of audio files, returns `SongInfo[]` |
| `play_song` / `pause_song` / `resume_song` / `stop_song` | Playback control |
| `seek_to` / `set_volume` | Position and volume |
| `get_player_status` | Poll current position, playing state |
| `play_next` / `play_prev` | Auto-advance in playlist |
| `play_url` | Download URL to memory, then stream |
| `fetch_text` | HTTP GET for LX scripts (bypasses CORS) |
| `get_song_meta` | Extract cover art + lyrics from local file |

## Key Patterns

- **Status polling**: JS polls `get_player_status` every 500ms via `pollStatus()`. When `is_stopped` is true and a song is loaded, it auto-advances.
- **Folder filtering**: `buildDisplayedSongs()` returns either the active folder's songs or all songs flattened. `createPlaybackSnapshot()` captures the current queue at play time.
- **Playlist sync**: `playNext`/`playPrev` are handled server-side in Rust (modular arithmetic on `current_index`). JS state is updated via the returned `SongInfo`.
