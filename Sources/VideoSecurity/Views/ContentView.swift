import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recorder = VideoRecorder()
    @State private var notificationManager = NotificationManager()
    @State private var sleepPreventer = SleepPreventer()

    @State private var storageURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
    @State private var keepDisplayAwake = UserDefaults.standard.bool(forKey: "keepDisplayAwake")
    @State private var recordingMode: RecordingMode = .continuous
    @StateObject private var languageStore = LanguageStore()
    @State private var showSettings = false
    @State private var statusKind: StatusKind = .ready
    @State private var motionIndicator = false

    private var lang: ResolvedLanguage { languageStore.resolved }

    var body: some View {
        VStack(spacing: 0) {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .frame(minWidth: 640, minHeight: 360)
                .overlay(alignment: .topLeading) {
                    if motionIndicator {
                        Label(L10n.t(.motionBanner, lang), systemImage: "exclamationmark.triangle.fill")
                            .padding(8)
                            .background(.red.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: motionIndicator)

            Divider()

            // Control bar
            HStack(spacing: 16) {
                // Recording mode
                Picker(L10n.t(.mode, lang), selection: $recordingMode) {
                    Text(L10n.t(.continuous, lang)).tag(RecordingMode.continuous)
                    Text(L10n.t(.motionMode, lang)).tag(RecordingMode.motionOnly)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .disabled(recorder.isRecording)

                Spacer()

                // Status
                Text(statusKind.text(lang))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                // Buttons
                Button {
                    startRecording()
                } label: {
                    Label(L10n.t(.record, lang), systemImage: "record.circle")
                        .foregroundStyle(recorder.isRecording ? .gray : .red)
                }
                .disabled(recorder.isRecording)
                .keyboardShortcut("r", modifiers: [.command])

                Button {
                    stopRecording()
                } label: {
                    Label(L10n.t(.stop, lang), systemImage: "stop.circle")
                }
                .disabled(!recorder.isRecording)
                .keyboardShortcut(".", modifiers: [.command])

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                cameraManager: cameraManager,
                recorder: recorder,
                notificationManager: $notificationManager,
                storageURL: $storageURL,
                languageStore: languageStore,
                keepDisplayAwake: $keepDisplayAwake
            )
        }
        .onAppear {
            setupCallbacks()
            if let cam = cameraManager.selectedCamera {
                cameraManager.startSession(with: cam)
            }
        }
        .onDisappear {
            cameraManager.stopSession()
            sleepPreventer.allow()
        }
        .onChange(of: keepDisplayAwake) { _, value in
            UserDefaults.standard.set(value, forKey: "keepDisplayAwake")
            if recorder.isRecording {
                sleepPreventer.prevent(keepDisplayAwake: value)
            }
        }
        .onChange(of: recorder.isMotionRecording) { _, active in
            if active {
                statusKind = .motionRecording
                motionIndicator = true
                notificationManager.sendMotionAlert(at: Date())
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    motionIndicator = false
                }
            } else if recorder.isRecording, recordingMode == .motionOnly {
                statusKind = .waitingForMotion
            }
        }
    }

    // MARK: - Start / stop

    private func startRecording() {
        recorder.storageURL = storageURL
        recorder.mode = recordingMode
        sleepPreventer.prevent(keepDisplayAwake: keepDisplayAwake)

        if recordingMode == .continuous {
            recorder.startContinuous()
            statusKind = .recording
        } else {
            recorder.startMotionMode()
            statusKind = .waitingForMotion
        }
    }

    private func stopRecording() {
        recorder.stop()
        sleepPreventer.allow()
        statusKind = .stopped
        motionIndicator = false
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        let recorder = self.recorder
        cameraManager.onVideoSample = { sample in
            recorder.processVideo(sample)
        }
        cameraManager.onAudioSample = { sample in
            recorder.processAudio(sample)
        }
    }
}

private enum StatusKind {
    case ready
    case recording
    case waitingForMotion
    case stopped
    case motionRecording

    func text(_ lang: ResolvedLanguage) -> String {
        switch self {
        case .ready: return L10n.t(.ready, lang)
        case .recording: return L10n.t(.recording, lang)
        case .waitingForMotion: return L10n.t(.waitingForMotion, lang)
        case .stopped: return L10n.t(.stopped, lang)
        case .motionRecording: return L10n.t(.motionRecording, lang)
        }
    }
}
