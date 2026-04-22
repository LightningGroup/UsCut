import Foundation

struct RenderSuccess {
    let requestId: String
    let outputPath: String
    let durationMs: Int
    let width: Int
    let height: Int
    let fileSizeBytes: Int

    func toDictionary() -> [String: Any] {
        return [
            "requestId": requestId,
            "outputPath": outputPath,
            "durationMs": durationMs,
            "width": width,
            "height": height,
            "fileSizeBytes": fileSizeBytes,
        ]
    }
}
