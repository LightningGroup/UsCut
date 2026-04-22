import CoreGraphics
import Foundation

enum VideoInstructionBuilder {
    /// Computes the affine transform that maps a source video frame of
    /// `natural` pixel size (with `preferred` preferredTransform applied)
    /// onto a `target` render canvas using aspect-fill semantics.
    ///
    /// Steps:
    /// 1. Apply preferredTransform (rotation/flip from capture orientation).
    /// 2. Shift so the oriented content starts at (0,0) — preferredTransform
    ///    often leaves content in a shifted quadrant.
    /// 3. Scale by `max(targetW/orientedW, targetH/orientedH)` to fill canvas.
    /// 4. Translate so the scaled content is centered on the canvas.
    static func aspectFillTransform(
        preferred: CGAffineTransform,
        natural: CGSize,
        target: CGSize
    ) -> CGAffineTransform {
        let orientedRect = CGRect(origin: .zero, size: natural).applying(preferred)
        let orientedW = abs(orientedRect.width)
        let orientedH = abs(orientedRect.height)
        guard orientedW > 0, orientedH > 0 else { return preferred }

        var t = preferred
        t = t.concatenating(
            CGAffineTransform(
                translationX: -orientedRect.minX,
                y: -orientedRect.minY
            )
        )
        let scale = max(target.width / orientedW, target.height / orientedH)
        t = t.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        let scaledW = orientedW * scale
        let scaledH = orientedH * scale
        let tx = (target.width - scaledW) / 2.0
        let ty = (target.height - scaledH) / 2.0
        t = t.concatenating(CGAffineTransform(translationX: tx, y: ty))
        return t
    }
}
