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

    // MARK: - macOS 三栏布局

    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            } detail: {
                SearchView()
            }
            MiniPlayerView()
        }
        .frame(minWidth: 900, minHeight: 600)
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
                    Label("设置", systemImage: "gearshape")
                }
            }
            .padding(.bottom, playerVM.audioPlayer.currentSong != nil ? 64 : 0)

            if playerVM.audioPlayer.currentSong != nil {
                MiniPlayerView()
            }
        }
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

/// macOS 侧边栏
struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink {
                SearchView()
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
            }

            NavigationLink {
                PlaylistListView()
            } label: {
                Label("歌单", systemImage: "music.note.list")
            }

            NavigationLink {
                SettingsView()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MusicBox")
    }
}
