import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Combine

enum RecordingMode {
    case continuous
    case motionOnly
}

final class VideoRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isMotionRecording = false

    var storageURL: URL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
    var mode: RecordingMode = .continuous
    var preMotionSeconds: Double = 10
    var postMotionSeconds: Double = 10
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var sessionStarted = false

    private let motionDetector = MotionDetector()
    private var preBuffer: CircularFrameBuffer

    // Timer to stop recording postMotionSeconds after the last motion event
    private var postMotionTimer: DispatchSourceTimer?
    private let recorderQueue = DispatchQueue(label: "vs.recorder", qos: .userInteractive)

    /// Logic flag updated on the sample path immediately (not only on main).
    private var motionRecordingActive = false

    // Video parameters — captured from the first frame
    private var videoFormatDescription: CMFormatDescription?
    private var audioFormatDescription: CMFormatDescription?

    var sensitivity: Double {
        get { motionDetector.sensitivity }
        set { motionDetector.sensitivity = newValue }
    }

    init() {
        // Buffer capacity = 30fps * 10 seconds
        preBuffer = CircularFrameBuffer(capacity: 300)
    }

    // MARK: - Public API

    func startContinuous() {
        guard !isRecording else { return }
        mode = .continuous
        isRecording = true
    }

    func startMotionMode() {
        guard !isRecording else { return }
        mode = .motionOnly
        isRecording = true
        motionRecordingActive = false
        motionDetector.reset()
        preBuffer.clear()
    }

    func stop() {
        postMotionTimer?.cancel()
        postMotionTimer = nil
        motionRecordingActive = false
        isRecording = false
        isMotionRecording = false

        recorderQueue.async { [weak self] in
            self?.finalizeWriter {}
        }
    }

    // MARK: - Sample handling

    func processVideo(_ sample: CMSampleBuffer) {
        guard isRecording else { return }

        if videoFormatDescription == nil {
            videoFormatDescription = CMSampleBufferGetFormatDescription(sample)
        }

        switch mode {
        case .continuous:
            if assetWriter == nil {
                openNewFile(using: sample)
            }
            writeSample(sample, to: videoWriterInput)

        case .motionOnly:
            if motionRecordingActive {
                writeSample(sample, to: videoWriterInput)
                if motionDetector.detect(in: sample) {
                    resetPostMotionTimer()
                }
            } else {
                preBuffer.push(sample)
                if motionDetector.detect(in: sample) {
                    beginMotionRecording()
                }
            }
        }
    }

    func processAudio(_ sample: CMSampleBuffer) {
        guard isRecording else { return }
        if audioFormatDescription == nil {
            audioFormatDescription = CMSampleBufferGetFormatDescription(sample)
        }
        if mode == .continuous || motionRecordingActive {
            writeSample(sample, to: audioWriterInput)
        }
    }

    // MARK: - Internal logic

    private func beginMotionRecording() {
        guard !motionRecordingActive else { return }

        let buffered = preBuffer.drain()
        preBuffer.clear()

        let dimensionSample = buffered.last
        openNewFile(using: dimensionSample)

        motionRecordingActive = true

        for s in buffered {
            writeSample(s, to: videoWriterInput)
        }

        resetPostMotionTimer()

        DispatchQueue.main.async { [weak self] in
            self?.isMotionRecording = true
        }
    }

    private func resetPostMotionTimer() {
        postMotionTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: recorderQueue)
        timer.schedule(deadline: .now() + postMotionSeconds)
        timer.setEventHandler { [weak self] in
            self?.finalizeWriter {
                DispatchQueue.main.async {
                    self?.motionRecordingActive = false
                    self?.isMotionRecording = false
                    self?.preBuffer.clear()
                    self?.motionDetector.reset()
                }
            }
        }
        timer.resume()
        postMotionTimer = timer
    }

    private func openNewFile(using sample: CMSampleBuffer?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let prefix = mode == .continuous ? "continuous" : "motion"
        let name = "\(prefix)_\(formatter.string(from: Date())).mov"
        let url = storageURL.appendingPathComponent(name)

        let size = videoDimensions(from: sample)
        guard size.width > 0, size.height > 0 else {
            print("VideoRecorder: missing video dimensions")
            return
        }

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 4_000_000
                ]
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true

            guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
                print("VideoRecorder: cannot add writer inputs")
                return
            }
            writer.add(videoInput)
            writer.add(audioInput)

            guard writer.startWriting() else {
                print("VideoRecorder: startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
                return
            }

            assetWriter = writer
            videoWriterInput = videoInput
            audioWriterInput = audioInput
            sessionStarted = false
        } catch {
            print("VideoRecorder: failed to create file: \(error)")
        }
    }

    private func videoDimensions(from sample: CMSampleBuffer?) -> (width: Int, height: Int) {
        if let sample,
           let imageBuffer = CMSampleBufferGetImageBuffer(sample) {
            return (CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))
        }
        if let desc = videoFormatDescription {
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            return (Int(dims.width), Int(dims.height))
        }
        return (0, 0)
    }

    private func writeSample(_ sample: CMSampleBuffer, to input: AVAssetWriterInput?) {
        guard let writer = assetWriter, let input = input else { return }
        guard writer.status == .writing else {
            if writer.status == .failed {
                print("VideoRecorder: writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            }
            return
        }

        if !sessionStarted {
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        if input.isReadyForMoreMediaData {
            input.append(sample)
        }
    }

    private func finalizeWriter(completion: @escaping () -> Void) {
        guard let writer = assetWriter else {
            completion()
            return
        }
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        writer.finishWriting {
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil
            self.sessionStarted = false
            completion()
        }
    }
}
