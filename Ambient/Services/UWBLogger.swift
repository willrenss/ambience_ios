import Foundation
import Observation

// Shared timestamped log for UWB debugging — mirrors UWBDemo's logLines / logTextView.
// All methods are MainActor; call from background via Task { @MainActor in }.
@Observable
@MainActor
final class UWBLogger {
    static let shared = UWBLogger()
    private(set) var lines: [String] = []

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func append(_ message: String) {
        let ts = df.string(from: Date())
        lines.append("[\(ts)] \(message)")
        if lines.count > 60 { lines.removeFirst() }
    }

    func clear() { lines.removeAll() }

    var text: String { lines.joined(separator: "\n") }
}
