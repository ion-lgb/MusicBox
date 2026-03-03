import SwiftUI

// MARK: - 设计系统

enum DS {
    // 平台品牌色
    static let neteaseRed = Color(red: 0.87, green: 0.15, blue: 0.17)
    static let qqGreen = Color(red: 0.19, green: 0.78, blue: 0.35)
    static let kugouBlue = Color(red: 0.15, green: 0.56, blue: 0.95)
    static let miguPink = Color(red: 0.95, green: 0.30, blue: 0.55)

    static func color(for platform: MusicPlatform) -> Color {
        switch platform {
        case .netease: return neteaseRed
        case .qq: return qqGreen
        case .kugou: return kugouBlue
        case .migu: return miguPink
        }
    }

    static func gradient(for platform: MusicPlatform) -> LinearGradient {
        let c = color(for: platform)
        return LinearGradient(colors: [c, c.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 封面组件

struct AlbumCover: View {
    let platform: MusicPlatform
    let size: CGFloat
    var isCircle: Bool = false

    var body: some View {
        Group {
            if isCircle {
                Circle()
                    .fill(DS.gradient(for: platform))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.3, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .shadow(color: DS.color(for: platform).opacity(0.4), radius: size * 0.1, y: size * 0.04)
            } else {
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(DS.gradient(for: platform))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.3, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .shadow(color: DS.color(for: platform).opacity(0.35), radius: 8, y: 4)
            }
        }
    }
}

// MARK: - 平台标签

struct PlatformTag: View {
    let platform: MusicPlatform
    var small: Bool = false

    var body: some View {
        Text(platform.displayName)
            .font(small ? .system(size: 9, weight: .semibold) : .caption2.bold())
            .padding(.horizontal, small ? 5 : 7)
            .padding(.vertical, small ? 2 : 3)
            .background(DS.color(for: platform))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - macOS 适配

#if os(macOS)
extension Color {
    static let secondarySystemFill = Color(nsColor: .controlBackgroundColor)
    static let systemGroupedBackground = Color(nsColor: .windowBackgroundColor)
    static let secondarySystemGroupedBackground = Color(nsColor: .controlBackgroundColor)
}

extension NSColor {
    static let secondarySystemFill = NSColor.controlBackgroundColor
}
#endif

// MARK: - TimeInterval 扩展

extension TimeInterval {
    var formattedTime: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }
}
