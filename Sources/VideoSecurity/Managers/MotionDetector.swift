import CoreMedia
import CoreVideo
import Accelerate
import Foundation

/// Detects motion by comparing per-pixel differences of grayscale frames.
/// Uses a downsampled luma grid so Continuity / high-res cameras stay light on CPU.
final class MotionDetector {
    /// 0.0 — insensitive, 1.0 — maximum sensitivity.
    var sensitivity: Double = 0.5

    /// Max width of the detection grid (height scales with aspect).
    private let maxDetectWidth = 160

    private var previousLuma: [Float]?
    private var previousWidth = 0
    private var previousHeight = 0

    /// Per-pixel luma delta (0–255) that counts as "changed".
    /// Higher sensitivity → smaller delta required.
    private var pixelDelta: Float {
        Float((1.0 - sensitivity) * 25.0 + 10.0)
    }

    /// Minimum fraction of grid pixels that must exceed pixelDelta.
    /// Higher sensitivity → smaller fraction required.
    private var minChangedFraction: Float {
        Float((1.0 - sensitivity) * 0.04 + 0.005)
    }

    /// Returns true if motion is detected.
    func detect(in sampleBuffer: CMSampleBuffer) -> Bool {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return false }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        guard let current = extractLuma(from: imageBuffer) else { return false }
        let width = current.width
        let height = current.height
        let pixelCount = width * height
        let luma = current.luma

        guard let prev = previousLuma,
              previousWidth == width,
              previousHeight == height else {
            previousLuma = luma
            previousWidth = width
            previousHeight = height
            return false
        }

        var diff = [Float](repeating: 0, count: pixelCount)
        vDSP_vsub(prev, 1, luma, 1, &diff, 1, vDSP_Length(pixelCount))
        var absDiff = [Float](repeating: 0, count: pixelCount)
        vDSP_vabs(diff, 1, &absDiff, 1, vDSP_Length(pixelCount))

        let delta = pixelDelta
        var changed = 0
        for value in absDiff where value > delta {
            changed += 1
        }

        previousLuma = luma

        return Float(changed) / Float(pixelCount) >= minChangedFraction
    }

    func reset() {
        previousLuma = nil
        previousWidth = 0
        previousHeight = 0
    }

    // MARK: - Luma extraction

    private struct LumaBuffer {
        var luma: [Float]
        let width: Int
        let height: Int
    }

    private func gridSize(fullWidth: Int, fullHeight: Int) -> (width: Int, height: Int, step: Int) {
        let step = max(1, (fullWidth + maxDetectWidth - 1) / maxDetectWidth)
        let width = max(1, fullWidth / step)
        let height = max(1, fullHeight / step)
        return (width, height, step)
    }

    private func extractLuma(from imageBuffer: CVPixelBuffer) -> LumaBuffer? {
        let planeCount = CVPixelBufferGetPlaneCount(imageBuffer)
        if planeCount >= 1 {
            return extractLumaFromPlane0(imageBuffer)
        }

        let format = CVPixelBufferGetPixelFormatType(imageBuffer)
        switch format {
        case kCVPixelFormatType_32BGRA:
            return extractLumaFromBGRA(imageBuffer)
        case kCVPixelFormatType_32ARGB:
            return extractLumaFromARGB(imageBuffer)
        default:
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            if width > 0, height > 0, bytesPerRow >= width * 4 {
                return extractLumaFromBGRA(imageBuffer)
            }
            return nil
        }
    }

    private func extractLumaFromPlane0(_ imageBuffer: CVPixelBuffer) -> LumaBuffer? {
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else { return nil }
        let fullWidth = CVPixelBufferGetWidthOfPlane(imageBuffer, 0)
        let fullHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
        guard fullWidth > 0, fullHeight > 0 else { return nil }

        let grid = gridSize(fullWidth: fullWidth, fullHeight: fullHeight)
        var current = [Float](repeating: 0, count: grid.width * grid.height)

        baseAddress.withMemoryRebound(to: UInt8.self, capacity: bytesPerRow * fullHeight) { ptr in
            for y in 0..<grid.height {
                let srcRow = ptr.advanced(by: y * grid.step * bytesPerRow)
                for x in 0..<grid.width {
                    current[y * grid.width + x] = Float(srcRow[x * grid.step])
                }
            }
        }

        return LumaBuffer(luma: current, width: grid.width, height: grid.height)
    }

    private func extractLumaFromBGRA(_ imageBuffer: CVPixelBuffer) -> LumaBuffer? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        let fullWidth = CVPixelBufferGetWidth(imageBuffer)
        let fullHeight = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard fullWidth > 0, fullHeight > 0 else { return nil }

        let grid = gridSize(fullWidth: fullWidth, fullHeight: fullHeight)
        var current = [Float](repeating: 0, count: grid.width * grid.height)

        baseAddress.withMemoryRebound(to: UInt8.self, capacity: bytesPerRow * fullHeight) { ptr in
            for y in 0..<grid.height {
                let row = ptr.advanced(by: y * grid.step * bytesPerRow)
                for x in 0..<grid.width {
                    let p = row.advanced(by: x * grid.step * 4)
                    let b = Float(p[0])
                    let g = Float(p[1])
                    let r = Float(p[2])
                    current[y * grid.width + x] = 0.299 * r + 0.587 * g + 0.114 * b
                }
            }
        }

        return LumaBuffer(luma: current, width: grid.width, height: grid.height)
    }

    private func extractLumaFromARGB(_ imageBuffer: CVPixelBuffer) -> LumaBuffer? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        let fullWidth = CVPixelBufferGetWidth(imageBuffer)
        let fullHeight = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard fullWidth > 0, fullHeight > 0 else { return nil }

        let grid = gridSize(fullWidth: fullWidth, fullHeight: fullHeight)
        var current = [Float](repeating: 0, count: grid.width * grid.height)

        baseAddress.withMemoryRebound(to: UInt8.self, capacity: bytesPerRow * fullHeight) { ptr in
            for y in 0..<grid.height {
                let row = ptr.advanced(by: y * grid.step * bytesPerRow)
                for x in 0..<grid.width {
                    let p = row.advanced(by: x * grid.step * 4)
                    let r = Float(p[1])
                    let g = Float(p[2])
                    let b = Float(p[3])
                    current[y * grid.width + x] = 0.299 * r + 0.587 * g + 0.114 * b
                }
            }
        }

        return LumaBuffer(luma: current, width: grid.width, height: grid.height)
    }
}
