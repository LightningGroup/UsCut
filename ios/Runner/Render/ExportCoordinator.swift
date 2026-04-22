import AVFoundation
import Foundation

enum ExportCoordinator {
    static func export(
        composition: AVComposition,
        videoComposition: AVVideoComposition,
        outputURL: URL
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw RenderError.exportFailed(underlying: "nil AVAssetExportSession")
        }

        session.videoComposition = videoComposition
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        switch session.status {
        case .completed:
            return
        case .failed:
            throw RenderError.exportFailed(
                underlying: session.error?.localizedDescription ?? "unknown"
            )
        case .cancelled:
            throw RenderError.exportCancelled
        default:
            throw RenderError.exportFailed(
                underlying: "unexpected status \(session.status.rawValue)"
            )
        }
    }
}
