import Flutter
import Foundation

enum RenderError: Error {
    case invalidRequest(field: String)
    case clipCountInvalid(count: Int)
    case sourceNotFound(index: Int, path: String)
    case sourceUnreadable(index: Int)
    case trimOutOfRange(index: Int, sourceDurationMs: Int, requestedEndMs: Int)
    case compositionBuildFailed(index: Int)
    case exportFailed(underlying: String)
    case exportCancelled
    case outputWriteFailed(outputDir: String)

    func toFlutterError() -> FlutterError {
        switch self {
        case .invalidRequest(let field):
            return FlutterError(
                code: "INVALID_REQUEST",
                message: "Malformed request JSON",
                details: ["field": field]
            )
        case .clipCountInvalid(let count):
            return FlutterError(
                code: "CLIP_COUNT_INVALID",
                message: "Expected 1..8 clips",
                details: ["count": count]
            )
        case .sourceNotFound(let index, let path):
            return FlutterError(
                code: "SOURCE_NOT_FOUND",
                message: "Source file missing",
                details: ["index": index, "path": path]
            )
        case .sourceUnreadable(let index):
            return FlutterError(
                code: "SOURCE_UNREADABLE",
                message: "AVAsset failed to load video track",
                details: ["index": index]
            )
        case .trimOutOfRange(let index, let sourceMs, let requestedEndMs):
            return FlutterError(
                code: "TRIM_OUT_OF_RANGE",
                message: "startMs+durationMs exceeds asset duration",
                details: [
                    "index": index,
                    "sourceDurationMs": sourceMs,
                    "requestedEndMs": requestedEndMs,
                ]
            )
        case .compositionBuildFailed(let index):
            return FlutterError(
                code: "COMPOSITION_BUILD_FAILED",
                message: "Failed to insert clip into composition",
                details: ["index": index]
            )
        case .exportFailed(let underlying):
            return FlutterError(
                code: "EXPORT_FAILED",
                message: "AVAssetExportSession failed",
                details: ["underlyingError": underlying]
            )
        case .exportCancelled:
            return FlutterError(
                code: "EXPORT_CANCELLED",
                message: "Export cancelled",
                details: nil
            )
        case .outputWriteFailed(let dir):
            return FlutterError(
                code: "OUTPUT_WRITE_FAILED",
                message: "Cannot write to outputDir",
                details: ["outputDir": dir]
            )
        }
    }
}
