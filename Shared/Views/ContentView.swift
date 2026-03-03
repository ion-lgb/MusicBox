import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(PlaylistViewModel.self) private var playlistVM
    @Environment(MusicSourceEngine.self) private var engine

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            } detail: {
                SearchView()
            }
            if playerVM.audioPlayer.currentSong != nil {
                MiniPlayerView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .modelContainer(for: [Playlist.self, PlaylistItem.self])
        .onAppear {
            if let ctx = try? ModelContext(ModelContainer(for: Playlist.self, PlaylistItem.self)) {
                playlistVM.setModelContext(ctx)
            }
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack { SearchView() }
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                NavigationStack { PlaylistListView() }
                    .tabItem { Label("歌单", systemImage: "music.note.list") }
                NavigationStack { SettingsView() }
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
            }
            .tint(.purple)
            .safeAreaPadding(.bottom, playerVM.audioPlayer.currentSong != nil ? 64 : 0)

            if playerVM.audioPlayer.currentSong != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let error = playerVM.playError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.gradient, in: Capsule())
                .padding(.top, 50)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: playerVM.playError)
            }
        }
        .animation(.spring(duration: 0.35), value: playerVM.audioPlayer.currentSong != nil)
        .modelContainer(for: [Playlist.self, PlaylistItem.self])
        .sheet(isPresented: Binding(
            get: { playerVM.showFullPlayer },
            set: { playerVM.showFullPlayer = $0 }
        )) {
            FullPlayerView()
        }
    }
    #endif
}

// MARK: - 侧边栏

struct SidebarView: View {
    var body: some View {
        List {
            Section("发现") {
                NavigationLink { SearchView() } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
            }
            Section("我的") {
                NavigationLink { PlaylistListView() } label: {
                    Label("歌单", systemImage: "music.note.list")
                }
            }
            Section {
                NavigationLink { SettingsView() } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MusicBox")
    }
}
