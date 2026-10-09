import AVFoundation
import CoreMedia
import Combine

final class CameraManager: NSObject, ObservableObject {
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCamera: AVCaptureDevice?
    @Published var isRunning = false

    let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioInput: AVCaptureDeviceInput? = {
        guard let mic = AVCaptureDevice.default(for: .audio) else { return nil }
        return try? AVCaptureDeviceInput(device: mic)
    }()

    private let outputQueue = DispatchQueue(label: "vs.camera.output", qos: .userInteractive)

    // External frame handlers
    var onVideoSample: ((CMSampleBuffer) -> Void)?
    var onAudioSample: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
        refreshCameras()
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func refreshCameras() {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices
        if selectedCamera == nil {
            selectedCamera = availableCameras.first
        }
    }

    func startSession(with camera: AVCaptureDevice) {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Remove the previous input
        if let old = videoInput {
            session.removeInput(old)
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            videoInput = input
        } catch {
            session.commitConfiguration()
            return
        }

        if let ai = audioInput, session.canAddInput(ai) {
            session.addInput(ai)
        }
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stopSession() {
        session.stopRunning()
        isRunning = false
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate,
                         AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output === videoOutput {
            onVideoSample?(sampleBuffer)
        } else if output === audioOutput {
            onAudioSample?(sampleBuffer)
        }
    }
}
