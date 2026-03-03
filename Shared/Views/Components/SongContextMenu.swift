import SwiftUI

/// 歌曲右键菜单
struct SongContextMenu: ViewModifier {
    let song: Song
    @Environment(PlayerViewModel.self) private var playerVM
    @Environment(MusicSourceEngine.self) private var engine

    func body(content: Content) -> some View {
        content.contextMenu {
            // 播放
            Button {
                Task { await playerVM.playSong(song, engine: engine) }
            } label: {
                Label("播放", systemImage: "play.fill")
            }

            // 下一首播放
            Button {
                playerVM.audioPlayer.insertNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            // 添加到队列
            Button {
                playerVM.audioPlayer.addToQueue(song)
            } label: {
                Label("添加到播放队列", systemImage: "text.append")
            }

            Divider()

            // 复制歌曲信息
            Button {
                let info = "\(song.name) - \(song.artist)"
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info, forType: .string)
                #else
                UIPasteboard.general.string = info
                #endif
            } label: {
                Label("复制歌曲信息", systemImage: "doc.on.doc")
            }
        }
    }
}

extension View {
    func songContextMenu(_ song: Song) -> some View {
        modifier(SongContextMenu(song: song))
    }
}
