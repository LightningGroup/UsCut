import Foundation

struct RenderRequest: Codable {
    let requestId: String
    let outputDir: String
    let outputFilename: String
    let renderSize: RenderSize
    let frameRate: Int
    let clips: [RenderClip]

    static func decode(from raw: Any) throws -> RenderRequest {
        guard let dict = raw as? [String: Any] else {
            throw RenderError.invalidRequest(field: "root")
        }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            throw RenderError.invalidRequest(field: "json-serialize")
        }
        do {
            return try JSONDecoder().decode(RenderRequest.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw RenderError.invalidRequest(field: key.stringValue)
        } catch let DecodingError.typeMismatch(_, ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            throw RenderError.invalidRequest(field: path.isEmpty ? "type-mismatch" : path)
        } catch let DecodingError.valueNotFound(_, ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            throw RenderError.invalidRequest(field: path.isEmpty ? "value-missing" : path)
        } catch {
            throw RenderError.invalidRequest(field: "decode: \(error.localizedDescription)")
        }
    }

    func validate() throws {
        guard !clips.isEmpty else {
            throw RenderError.clipCountInvalid(count: 0)
        }
        // Stage 1 uses 6 clips (3A + 3B). Upper bound of 8 leaves room for
        // Stage 2 asymmetric-A/B experiments without channel changes.
        guard clips.count <= 8 else {
            throw RenderError.clipCountInvalid(count: clips.count)
        }
        guard renderSize.width > 0, renderSize.height > 0 else {
            throw RenderError.invalidRequest(field: "renderSize")
        }
        guard renderSize.width % 2 == 0, renderSize.height % 2 == 0 else {
            throw RenderError.invalidRequest(field: "renderSize must be even")
        }
        guard frameRate > 0, frameRate <= 60 else {
            throw RenderError.invalidRequest(field: "frameRate")
        }
        for clip in clips {
            guard FileManager.default.fileExists(atPath: clip.sourcePath) else {
                throw RenderError.sourceNotFound(index: clip.index, path: clip.sourcePath)
            }
            guard clip.durationMs > 0 else {
                throw RenderError.invalidRequest(field: "clips[\(clip.index)].durationMs")
            }
            guard clip.startMs >= 0 else {
                throw RenderError.invalidRequest(field: "clips[\(clip.index)].startMs")
            }
        }
    }
}
