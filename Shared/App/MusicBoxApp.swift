import SwiftUI

@main
struct MusicBoxApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var playlistViewModel = PlaylistViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var musicSourceEngine = MusicSourceEngine()
    @State private var downloadService = DownloadService()

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
        #endif
    }
}
