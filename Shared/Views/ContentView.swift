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
        macOSContent
            .frame(minWidth: 900, minHeight: 600)
            .modelContainer(for: [Playlist.self, PlaylistItem.self])
            .onAppear {
                if let ctx = try? ModelContext(ModelContainer(for: Playlist.self, PlaylistItem.self)) {
                    playlistVM.setModelContext(ctx)
                }
            }
            .modifier(MacOSKeyboardShortcuts())
    }

    private var macOSContent: some View {
        VStack(spacing: 0) {
            ZStack {
                mainNavigation
                lyricOverlay
                queueOverlay
            }
            errorBanner
            playerBar
        }
    }

    private var mainNavigation: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            SearchView()
        }
    }

    @ViewBuilder
    private var lyricOverlay: some View {
        if playerVM.showLyricPanel {
            HStack(spacing: 0) {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            playerVM.showLyricPanel = false
                        }
                    }
                LyricPanelView()
                    .frame(width: 400)
                    .transition(.move(edge: .trailing))
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var queueOverlay: some View {
        if playerVM.showPlayQueue {
            HStack(spacing: 0) {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            playerVM.showPlayQueue = false
                        }
                    }
                PlayQueueView()
                    .frame(width: 350)
                    .transition(.move(edge: .trailing))
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = playerVM.playError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.red.gradient)
        }
    }

    @ViewBuilder
    private var playerBar: some View {
        if playerVM.audioPlayer.currentSong != nil {
            MiniPlayerView()
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

// MARK: - macOS 快捷键（via menu commands）

#if os(macOS)
struct MacOSKeyboardShortcuts: ViewModifier {
    func body(content: Content) -> some View {
        content  // 快捷键在 MusicBoxApp 中通过 .commands 实现
    }
}
#endif

// MARK: - 侧边栏

struct SidebarView: View {
    var body: some View {
        List {
            Section("发现") {
                NavigationLink { SearchView() } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                NavigationLink { LeaderboardView() } label: {
                    Label("排行榜", systemImage: "chart.bar.fill")
                }
                NavigationLink { SongListView() } label: {
                    Label("歌单导入", systemImage: "rectangle.stack.badge.plus")
                }
            }
            Section("我的") {
                NavigationLink { PlaylistListView() } label: {
                    Label("歌单", systemImage: "music.note.list")
                }
                NavigationLink { DownloadView() } label: {
                    Label("下载", systemImage: "arrow.down.circle")
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
