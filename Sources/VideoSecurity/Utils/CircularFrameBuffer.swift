import CoreMedia
import Foundation

/// Ring buffer of CMSampleBuffer frames holding N seconds of video before an event.
final class CircularFrameBuffer: @unchecked Sendable {
    private var buffer: [CMSampleBuffer] = []
    private var writeIndex = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    func push(_ sample: CMSampleBuffer) {
        if buffer.count < capacity {
            buffer.append(sample)
        } else {
            buffer[writeIndex] = sample
        }
        writeIndex = (writeIndex + 1) % capacity
    }

    /// Returns frames in chronological order.
    func drain() -> [CMSampleBuffer] {
        guard !buffer.isEmpty else { return [] }
        if buffer.count < capacity {
            return buffer
        }
        let tail = Array(buffer[writeIndex...])
        let head = Array(buffer[..<writeIndex])
        return tail + head
    }

    func clear() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
    }
}
