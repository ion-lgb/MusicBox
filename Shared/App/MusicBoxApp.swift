import SwiftUI

@main
struct MusicBoxApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var playlistViewModel = PlaylistViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var musicSourceEngine = MusicSourceEngine()
    @State private var downloadService = DownloadService()

    init() {
        #if os(iOS)
        // iOS 26: 设置窗口背景色匹配内容，消除 Liquid Glass 卡片周围深色间隙
        UIWindow.appearance().backgroundColor = .systemBackground
        // 导航栏透明处理
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        // Tab bar 透明处理
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerViewModel)
                .environment(searchViewModel)
                .environment(playlistViewModel)
                .environment(settingsViewModel)
                .environment(musicSourceEngine)
                .environment(downloadService)
                .onAppear {
                    downloadService.setEngine(musicSourceEngine)
                }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            // 播放控制菜单
            CommandMenu("播放") {
                Button("播放 / 暂停") {
                    playerViewModel.togglePlayPause()
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("下一首") {
                    Task { await playerViewModel.playNext(engine: musicSourceEngine) }
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("上一首") {
                    Task { await playerViewModel.playPrevious(engine: musicSourceEngine) }
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("音量增大") {
                    playerViewModel.audioPlayer.volume = min(1.0, playerViewModel.audioPlayer.volume + 0.1)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("音量减小") {
                    playerViewModel.audioPlayer.volume = max(0.0, playerViewModel.audioPlayer.volume - 0.1)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Divider()

                Button("显示/隐藏歌词") {
                    withAnimation(.spring(duration: 0.3)) {
                        playerViewModel.showLyricPanel.toggle()
                    }
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
        #endif
    }
}
