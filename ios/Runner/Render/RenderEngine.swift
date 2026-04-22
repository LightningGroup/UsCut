import AVFoundation
import Foundation

enum RenderEngine {
    static func render(request: RenderRequest) async throws -> RenderSuccess {
        try request.validate()
        try ensureWritableDir(request.outputDir)

        let outputURL = URL(fileURLWithPath: request.outputDir)
            .appendingPathComponent(request.outputFilename)

        let bundle = try await CompositionBuilder.build(request: request)

        try await ExportCoordinator.export(
            composition: bundle.composition,
            videoComposition: bundle.videoComposition,
            outputURL: outputURL
        )

        let durationMs = Int(bundle.totalDuration.value * 1000 / Int64(bundle.totalDuration.timescale))
        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0

        return RenderSuccess(
            requestId: request.requestId,
            outputPath: outputURL.path,
            durationMs: durationMs,
            width: request.renderSize.width,
            height: request.renderSize.height,
            fileSizeBytes: size
        )
    }

    private static func ensureWritableDir(_ dir: String) throws {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)
        if !exists {
            do {
                try FileManager.default.createDirectory(
                    atPath: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                throw RenderError.outputWriteFailed(outputDir: dir)
            }
        } else if !isDir.boolValue {
            throw RenderError.outputWriteFailed(outputDir: dir)
        }
    }
}
