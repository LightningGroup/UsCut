import AVFoundation
import CoreGraphics
import Foundation

struct CompositionBundle {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let totalDuration: CMTime
}

enum CompositionBuilder {
    private static let timescale: CMTimeScale = 600

    static func build(request: RenderRequest) async throws -> CompositionBundle {
        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RenderError.compositionBuildFailed(index: -1)
        }

        let renderSize = CGSize(
            width: Double(request.renderSize.width),
            height: Double(request.renderSize.height)
        )

        var cursor = CMTime.zero
        var segments: [(timeRange: CMTimeRange, transform: CGAffineTransform)] = []

        let orderedClips = request.clips.sorted { $0.index < $1.index }

        for clip in orderedClips {
            let url = URL(fileURLWithPath: clip.sourcePath)
            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )

            let videoTracks: [AVAssetTrack]
            do {
                videoTracks = try await asset.loadTracks(withMediaType: .video)
            } catch {
                throw RenderError.sourceUnreadable(index: clip.index)
            }
            guard let srcTrack = videoTracks.first else {
                throw RenderError.sourceUnreadable(index: clip.index)
            }

            let assetDuration: CMTime
            let preferredTransform: CGAffineTransform
            let naturalSize: CGSize
            do {
                async let d = asset.load(.duration)
                async let pt = srcTrack.load(.preferredTransform)
                async let ns = srcTrack.load(.naturalSize)
                assetDuration = try await d
                preferredTransform = try await pt
                naturalSize = try await ns
            } catch {
                throw RenderError.sourceUnreadable(index: clip.index)
            }

            let clipStart = CMTime(
                value: CMTimeValue(Int64(clip.startMs) * Int64(timescale) / 1000),
                timescale: timescale
            )
            let clipDuration = CMTime(
                value: CMTimeValue(Int64(clip.durationMs) * Int64(timescale) / 1000),
                timescale: timescale
            )
            let requestedEnd = CMTimeAdd(clipStart, clipDuration)
            if CMTimeCompare(requestedEnd, assetDuration) > 0 {
                let sourceMs = Int(CMTimeGetSeconds(assetDuration) * 1000.0)
                throw RenderError.trimOutOfRange(
                    index: clip.index,
                    sourceDurationMs: sourceMs,
                    requestedEndMs: clip.startMs + clip.durationMs
                )
            }

            let srcRange = CMTimeRange(start: clipStart, duration: clipDuration)
            do {
                try compTrack.insertTimeRange(srcRange, of: srcTrack, at: cursor)
            } catch {
                throw RenderError.compositionBuildFailed(index: clip.index)
            }

            let transform = VideoInstructionBuilder.aspectFillTransform(
                preferred: preferredTransform,
                natural: naturalSize,
                target: renderSize
            )
            segments.append((
                timeRange: CMTimeRange(start: cursor, duration: clipDuration),
                transform: transform
            ))

            cursor = CMTimeAdd(cursor, clipDuration)
        }

        let videoComp = AVMutableVideoComposition()
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(request.frameRate)
        )
        videoComp.instructions = segments.map { seg in
            let ci = AVMutableVideoCompositionInstruction()
            ci.timeRange = seg.timeRange
            let li = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
            // Use .zero so the transform is active from the earliest possible
            // time inside this instruction's timeRange. Using seg.timeRange.start
            // has been reported to produce identity on the boundary frame.
            li.setTransform(seg.transform, at: .zero)
            ci.layerInstructions = [li]
            return ci
        }

        return CompositionBundle(
            composition: composition,
            videoComposition: videoComp,
            totalDuration: cursor
        )
    }
}
