import SwiftUI

// MARK: - Color hex 扩展

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 设计系统

enum DesignTokens {
    // 间距
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // 圆角
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20

    // 平台渐变色
    static func platformGradient(_ platform: MusicPlatform) -> LinearGradient {
        let baseColor = Color(hex: platform.iconColor) ?? .gray
        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // 主题渐变
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#6366F1")!, Color(hex: "#8B5CF6")!],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color(.secondarySystemFill)
}

// MARK: - 封面视图

struct AlbumArtView: View {
    let platform: MusicPlatform
    let size: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.platformGradient(platform))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}

// MARK: - 平台 Badge

struct PlatformBadge: View {
    let platform: MusicPlatform
    var compact: Bool = false

    var body: some View {
        Text(compact ? String(platform.displayName.prefix(1)) : platform.displayName)
            .font(compact ? .caption2.bold() : .caption.weight(.medium))
            .padding(.horizontal, compact ? 0 : 8)
            .padding(.vertical, compact ? 0 : 3)
            .frame(width: compact ? 22 : nil, height: compact ? 22 : nil)
            .background(Color(hex: platform.iconColor) ?? .gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 6))
    }
}

// MARK: - 系统颜色兼容

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

// MARK: - TimeInterval 格式化

extension TimeInterval {
    var formattedTime: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }
}
