import SwiftUI
import SwiftData

/// 主视图 - 根据平台自适应布局
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

    // MARK: - macOS 侧边栏 + 内容

    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 230)
            } detail: {
                SearchView()
            }

            if playerVM.audioPlayer.currentSong != nil {
                MiniPlayerView()
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .modelContainer(for: [Playlist.self, PlaylistItem.self])
        .onAppear {
            if let context = try? ModelContext(ModelContainer(for: Playlist.self, PlaylistItem.self)) {
                playlistVM.setModelContext(context)
            }
        }
    }
    #endif

    // MARK: - iOS Tab 布局

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack {
                    SearchView()
                }
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }

                NavigationStack {
                    PlaylistListView()
                }
                .tabItem {
                    Label("歌单", systemImage: "music.note.list")
                }

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
            .safeAreaPadding(.bottom, playerVM.audioPlayer.currentSong != nil ? 60 : 0)

            if playerVM.audioPlayer.currentSong != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

// MARK: - macOS 侧边栏

struct SidebarView: View {
    var body: some View {
        List {
            Section("发现") {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("搜索音乐", systemImage: "magnifyingglass")
                }
            }

            Section("我的") {
                NavigationLink {
                    PlaylistListView()
                } label: {
                    Label("歌单", systemImage: "music.note.list")
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MusicBox")
    }
}
