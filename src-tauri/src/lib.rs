use lofty::prelude::*;
use lofty::probe::Probe;
use rodio::{Decoder, OutputStream, Sink};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Cursor;
use std::path::Path;
use std::sync::mpsc;
use std::sync::Mutex;
use tauri::State;
use tauri_plugin_dialog::DialogExt;
use walkdir::WalkDir;
use base64::Engine as _;

// ============================================================
// Data Types
// ============================================================

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SongInfo {
    pub path: String,
    pub file_name: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: f64,
}

#[derive(Debug, Serialize, Clone)]
pub struct PlayerStatus {
    pub is_playing: bool,
    pub is_stopped: bool,
    pub current_song: Option<SongInfo>,
    pub current_index: Option<usize>,
    pub position: f64,
    pub duration: f64,
    pub volume: f32,
}

#[derive(Debug, Serialize, Clone)]
pub struct SongMeta {
    pub cover: String,   // base64 data URI or empty
    pub lyrics: String,  // embedded LRC/plain lyrics or empty
}

// ============================================================
// Audio Thread Communication
// ============================================================

enum AudioCommand {
    Play(String),        // file path
    PlayData(Vec<u8>),   // raw audio bytes (from URL download)
    Pause,
    Resume,
    Stop,
    Seek(f64),           // position in seconds
    SetVolume(f32),      // 0.0 - 1.0
    GetStatus(mpsc::Sender<AudioThreadStatus>),
}

#[derive(Debug)]
struct AudioThreadStatus {
    is_playing: bool,
    is_stopped: bool,
    position: f64,
}

// ============================================================
// Managed State (Send + Sync safe)
// ============================================================

pub struct AudioPlayer {
    cmd_tx: mpsc::Sender<AudioCommand>,
    current_song: Option<SongInfo>,
    playlist: Vec<SongInfo>,
    current_index: usize,
    volume: f32,
}

impl AudioPlayer {
    fn get_status(&self) -> PlayerStatus {
        let (tx, rx) = mpsc::channel();
        let thread_status = if self.cmd_tx.send(AudioCommand::GetStatus(tx)).is_ok() {
            rx.recv_timeout(std::time::Duration::from_millis(100))
                .unwrap_or(AudioThreadStatus {
                    is_playing: false,
                    is_stopped: true,
                    position: 0.0,
                })
        } else {
            AudioThreadStatus {
                is_playing: false,
                is_stopped: true,
                position: 0.0,
            }
        };

        PlayerStatus {
            is_playing: thread_status.is_playing,
            is_stopped: thread_status.is_stopped,
            current_song: self.current_song.clone(),
            current_index: if self.current_song.is_some() {
                Some(self.current_index)
            } else {
                None
            },
            position: thread_status.position,
            duration: self.current_song.as_ref().map(|s| s.duration).unwrap_or(0.0),
            volume: self.volume,
        }
    }
}

/// Spawn a dedicated audio thread that owns OutputStream (which is !Send in some cases).
/// All audio operations are controlled via mpsc channel.
fn spawn_audio_thread() -> mpsc::Sender<AudioCommand> {
    let (tx, rx) = mpsc::channel::<AudioCommand>();

    std::thread::spawn(move || {
        // OutputStream must live in this thread
        let (_stream, stream_handle) = OutputStream::try_default()
            .expect("无法初始化音频输出设备");

        let mut sink: Option<Sink> = None;
        let mut volume: f32 = 0.8;

        loop {
            match rx.recv() {
                Ok(AudioCommand::Play(path)) => {
                    // Stop old sink
                    if let Some(old) = sink.take() {
                        old.stop();
                    }
                    match fs::read(&path) {
                        Ok(data) => match Decoder::new(Cursor::new(data)) {
                            Ok(source) => {
                                match Sink::try_new(&stream_handle) {
                                    Ok(new_sink) => {
                                        new_sink.set_volume(volume);
                                        new_sink.append(source);
                                        sink = Some(new_sink);
                                    }
                                    Err(e) => eprintln!("Sink creation error: {}", e),
                                }
                            }
                            Err(e) => eprintln!("Decode error: {}", e),
                        },
                        Err(e) => eprintln!("File open error: {}", e),
                    }
                }
                Ok(AudioCommand::PlayData(data)) => {
                    println!("[Audio] PlayData received: {} bytes", data.len());
                    // Stop old sink
                    if let Some(old) = sink.take() {
                        old.stop();
                    }
                    match Decoder::new(Cursor::new(data)) {
                        Ok(source) => {
                            println!("[Audio] Decode OK, creating sink...");
                            match Sink::try_new(&stream_handle) {
                                Ok(new_sink) => {
                                    new_sink.set_volume(volume);
                                    new_sink.append(source);
                                    sink = Some(new_sink);
                                    println!("[Audio] Playing! volume={}", volume);
                                }
                                Err(e) => eprintln!("[Audio] Sink creation error: {}", e),
                            }
                        }
                        Err(e) => eprintln!("[Audio] Decode error: {}", e),
                    }
                }
                Ok(AudioCommand::Pause) => {
                    if let Some(s) = &sink {
                        s.pause();
                    }
                }
                Ok(AudioCommand::Resume) => {
                    if let Some(s) = &sink {
                        s.play();
                    }
                }
                Ok(AudioCommand::Stop) => {
                    if let Some(s) = sink.take() {
                        s.stop();
                    }
                }
                Ok(AudioCommand::Seek(pos)) => {
                    if let Some(s) = &sink {
                        if let Err(e) = s.try_seek(std::time::Duration::from_secs_f64(pos)) {
                            eprintln!("Seek error: {}", e);
                        }
                    }
                }
                Ok(AudioCommand::SetVolume(v)) => {
                    volume = v;
                    if let Some(s) = &sink {
                        s.set_volume(v);
                    }
                }
                Ok(AudioCommand::GetStatus(reply)) => {
                    let status = match &sink {
                        Some(s) => AudioThreadStatus {
                            is_playing: !s.is_paused() && !s.empty(),
                            is_stopped: s.empty(),
                            position: s.get_pos().as_secs_f64(),
                        },
                        None => AudioThreadStatus {
                            is_playing: false,
                            is_stopped: true,
                            position: 0.0,
                        },
                    };
                    let _ = reply.send(status);
                }
                Err(_) => break, // Channel closed, exit thread
            }
        }
    });

    tx
}

// ============================================================
// Scan / File Commands
// ============================================================

const AUDIO_EXTENSIONS: &[&str] = &["mp3", "flac", "wav", "ogg", "m4a", "aac", "wma"];

fn is_audio_file(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| AUDIO_EXTENSIONS.contains(&ext.to_lowercase().as_str()))
        .unwrap_or(false)
}

fn parse_song(path: &Path) -> Option<SongInfo> {
    let file_name = path.file_name()?.to_string_lossy().to_string();
    let path_str = path.to_string_lossy().to_string();

    match Probe::open(path).ok().and_then(|p| p.read().ok()) {
        Some(tagged_file) => {
            let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());
            let properties = tagged_file.properties();
            let title = tag
                .and_then(|t| t.title().map(|s| s.to_string()))
                .unwrap_or_else(|| {
                    path.file_stem()
                        .map(|s| s.to_string_lossy().to_string())
                        .unwrap_or_else(|| file_name.clone())
                });
            let artist = tag
                .and_then(|t| t.artist().map(|s| s.to_string()))
                .unwrap_or_default();
            let album = tag
                .and_then(|t| t.album().map(|s| s.to_string()))
                .unwrap_or_default();
            let duration = properties.duration().as_secs_f64();
            Some(SongInfo { path: path_str, file_name, title, artist, album, duration })
        }
        None => Some(SongInfo {
            path: path_str,
            title: path.file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or_else(|| file_name.clone()),
            file_name,
            artist: String::new(),
            album: String::new(),
            duration: 0.0,
        }),
    }
}

#[tauri::command]
fn get_song_meta(path: String) -> Result<SongMeta, String> {
    let p = Path::new(&path);
    if !p.is_file() { return Err("文件不存在".into()); }
    let tagged_file = Probe::open(p)
        .map_err(|e| e.to_string())?
        .read()
        .map_err(|e| e.to_string())?;
    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());
    // 封面
    let cover = tag.and_then(|t| {
        t.pictures().first().map(|pic| {
            let mime = match pic.mime_type() {
                Some(lofty::picture::MimeType::Png) => "image/png",
                Some(lofty::picture::MimeType::Bmp) => "image/bmp",
                Some(lofty::picture::MimeType::Gif) => "image/gif",
                Some(lofty::picture::MimeType::Tiff) => "image/tiff",
                _ => "image/jpeg",
            };
            let b64 = base64::engine::general_purpose::STANDARD.encode(pic.data());
            format!("data:{};base64,{}", mime, b64)
        })
    }).unwrap_or_default();
    // 歌词
    let lyrics = tag.and_then(|t| {
        use lofty::tag::ItemKey;
        t.get_string(&ItemKey::Lyrics).map(|s| s.to_string())
    }).unwrap_or_default();
    Ok(SongMeta { cover, lyrics })
}

#[tauri::command]
fn pick_folder(app: tauri::AppHandle) -> Option<String> {
    app.dialog().file().set_title("选择音乐文件夹").blocking_pick_folder().map(|f| f.to_string())
}

#[tauri::command]
fn scan_music_dir(path: String) -> Result<Vec<SongInfo>, String> {
    let dir = Path::new(&path);
    if !dir.is_dir() { return Err(format!("路径不是有效目录: {}", path)); }
    let mut songs: Vec<SongInfo> = Vec::new();
    for entry in WalkDir::new(dir).follow_links(true).into_iter().filter_map(|e| e.ok()) {
        let p = entry.path();
        if p.is_file() && is_audio_file(p) {
            if let Some(song) = parse_song(p) { songs.push(song); }
        }
    }
    songs.sort_by_cached_key(|s| s.title.to_lowercase());
    Ok(songs)
}

// ============================================================
// Playback Commands
// ============================================================

#[tauri::command]
fn play_song(
    path: String,
    index: usize,
    playlist: Vec<SongInfo>,
    player: State<'_, Mutex<AudioPlayer>>,
) -> Result<(), String> {
    let mut p = player.lock().map_err(|e| e.to_string())?;
    let song = playlist.iter().find(|s| s.path == path).cloned()
        .ok_or_else(|| "歌曲不在播放列表中".to_string())?;
    p.playlist = playlist;
    p.current_index = index;
    p.current_song = Some(song.clone());
    p.cmd_tx.send(AudioCommand::Play(song.path)).map_err(|e| e.to_string())
}

#[tauri::command]
fn pause_song(player: State<'_, Mutex<AudioPlayer>>) -> Result<(), String> {
    let p = player.lock().map_err(|e| e.to_string())?;
    p.cmd_tx.send(AudioCommand::Pause).map_err(|e| e.to_string())
}

#[tauri::command]
fn resume_song(player: State<'_, Mutex<AudioPlayer>>) -> Result<(), String> {
    let p = player.lock().map_err(|e| e.to_string())?;
    p.cmd_tx.send(AudioCommand::Resume).map_err(|e| e.to_string())
}

#[tauri::command]
fn stop_song(player: State<'_, Mutex<AudioPlayer>>) -> Result<(), String> {
    let mut p = player.lock().map_err(|e| e.to_string())?;
    p.current_song = None;
    p.cmd_tx.send(AudioCommand::Stop).map_err(|e| e.to_string())
}

#[tauri::command]
fn seek_to(position: f64, player: State<'_, Mutex<AudioPlayer>>) -> Result<(), String> {
    let p = player.lock().map_err(|e| e.to_string())?;
    p.cmd_tx.send(AudioCommand::Seek(position)).map_err(|e| e.to_string())
}

#[tauri::command]
fn set_volume(volume: f32, player: State<'_, Mutex<AudioPlayer>>) -> Result<(), String> {
    let mut p = player.lock().map_err(|e| e.to_string())?;
    p.volume = volume.clamp(0.0, 1.0);
    p.cmd_tx.send(AudioCommand::SetVolume(p.volume)).map_err(|e| e.to_string())
}

#[tauri::command]
fn get_player_status(player: State<'_, Mutex<AudioPlayer>>) -> Result<PlayerStatus, String> {
    let p = player.lock().map_err(|e| e.to_string())?;
    Ok(p.get_status())
}

#[tauri::command]
fn play_next(player: State<'_, Mutex<AudioPlayer>>) -> Result<Option<SongInfo>, String> {
    let mut p = player.lock().map_err(|e| e.to_string())?;
    if p.playlist.is_empty() { return Ok(None); }
    p.current_index = (p.current_index + 1) % p.playlist.len();
    let song = p.playlist[p.current_index].clone();
    p.current_song = Some(song.clone());
    p.cmd_tx.send(AudioCommand::Play(song.path.clone())).map_err(|e| e.to_string())?;
    Ok(Some(song))
}

#[tauri::command]
fn play_prev(player: State<'_, Mutex<AudioPlayer>>) -> Result<Option<SongInfo>, String> {
    let mut p = player.lock().map_err(|e| e.to_string())?;
    if p.playlist.is_empty() { return Ok(None); }
    p.current_index = if p.current_index == 0 { p.playlist.len() - 1 } else { p.current_index - 1 };
    let song = p.playlist[p.current_index].clone();
    p.current_song = Some(song.clone());
    p.cmd_tx.send(AudioCommand::Play(song.path.clone())).map_err(|e| e.to_string())?;
    Ok(Some(song))
}

#[tauri::command]
async fn play_url(
    url: String,
    song_info: SongInfo,
    index: usize,
    playlist: Vec<SongInfo>,
    player: State<'_, Mutex<AudioPlayer>>,
) -> Result<(), String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(60))
        .build()
        .map_err(|e| format!("创建客户端失败: {}", e))?;
    let data = client.get(&url).send().await
        .map_err(|e| format!("HTTP download error: {}", e))?
        .bytes().await
        .map_err(|e| format!("Read body error: {}", e))?
        .to_vec();

    let mut p = player.lock().map_err(|e| e.to_string())?;
    p.playlist = playlist;
    p.current_index = index;
    p.current_song = Some(song_info);
    p.cmd_tx.send(AudioCommand::PlayData(data)).map_err(|e| e.to_string())
}

#[tauri::command]
async fn fetch_text(url: String) -> Result<String, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| format!("创建客户端失败: {}", e))?;
    let resp = client.get(&url).send().await
        .map_err(|e| format!("请求失败: {}", e))?;
    let len = resp.content_length().unwrap_or(0);
    if len > 10 * 1024 * 1024 {
        return Err("脚本文件过大（>10MB）".into());
    }
    resp.text().await
        .map_err(|e| format!("读取响应失败: {}", e))
}

// ============================================================
// App Entry
// ============================================================

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let cmd_tx = spawn_audio_thread();

    let player = AudioPlayer {
        cmd_tx,
        current_song: None,
        playlist: Vec::new(),
        current_index: 0,
        volume: 0.8,
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_http::init())
        .manage(Mutex::new(player))
        .invoke_handler(tauri::generate_handler![
            pick_folder,
            scan_music_dir,
            play_song,
            pause_song,
            resume_song,
            stop_song,
            seek_to,
            set_volume,
            get_player_status,
            play_next,
            play_prev,
            play_url,
            fetch_text,
            get_song_meta,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
