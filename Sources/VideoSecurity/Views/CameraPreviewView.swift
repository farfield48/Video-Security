import SwiftUI
import AVFoundation
import AppKit

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.session = session
    }
}

final class PreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }

    private let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        previewLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
