import Foundation

/// LRC 歌词行
struct LyricLine: Identifiable {
    let id = UUID()
    let time: TimeInterval  // 秒
    let text: String
    let translation: String?
}

/// LRC 歌词解析器
struct LyricParser {
    /// 解析 LRC 格式歌词
    static func parse(_ lrcString: String) -> [LyricLine] {
        guard !lrcString.isEmpty else { return [] }

        var lines: [LyricLine] = []
        let rawLines = lrcString.components(separatedBy: "\n")

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 匹配 [mm:ss.xx] 或 [mm:ss.xxx] 格式
            let pattern = #"\[(\d{1,3}):(\d{2})[\.:]([\d]{2,3})\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))

            guard !matches.isEmpty else { continue }

            // 提取歌词文本（去掉所有时间标签）
            var text = trimmed
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    text.removeSubrange(range)
                }
            }
            text = text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            // 一行可能有多个时间标签
            for match in matches {
                guard let minRange = Range(match.range(at: 1), in: trimmed),
                      let secRange = Range(match.range(at: 2), in: trimmed),
                      let msRange = Range(match.range(at: 3), in: trimmed) else { continue }

                let min = Double(trimmed[minRange]) ?? 0
                let sec = Double(trimmed[secRange]) ?? 0
                var ms = Double(trimmed[msRange]) ?? 0

                // 如果毫秒是2位数，乘以10
                if trimmed[msRange].count == 2 { ms *= 10 }

                let time = min * 60 + sec + ms / 1000
                lines.append(LyricLine(time: time, text: text, translation: nil))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// 合并翻译歌词
    static func merge(original: [LyricLine], translation: String) -> [LyricLine] {
        let transLines = parse(translation)
        guard !transLines.isEmpty else { return original }

        return original.map { line in
            // 找最接近的翻译行
            let trans = transLines.min(by: { abs($0.time - line.time) < abs($1.time - line.time) })
            if let trans = trans, abs(trans.time - line.time) < 1.0 {
                return LyricLine(time: line.time, text: line.text, translation: trans.text)
            }
            return line
        }
    }

    /// 获取当前播放时间对应的歌词行索引
    static func currentIndex(for time: TimeInterval, in lines: [LyricLine]) -> Int {
        guard !lines.isEmpty else { return -1 }
        for i in (0..<lines.count).reversed() {
            if time >= lines[i].time {
                return i
            }
        }
        return 0
    }
}
