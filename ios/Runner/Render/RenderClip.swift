import Foundation

struct RenderSize: Codable {
    let width: Int
    let height: Int
}

struct RenderClip: Codable {
    let index: Int
    let sourcePath: String
    let startMs: Int
    let durationMs: Int
    let userTag: String
}
