import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var recorder: VideoRecorder
    @Binding var notificationManager: NotificationManager
    @Binding var storageURL: URL
    @ObservedObject var languageStore: LanguageStore
    @Binding var keepDisplayAwake: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var notifSettings: NotificationSettings
    @State private var sensitivity: Double
    @State private var keepDisplayAwakeDraft: Bool
    @State private var selectedCameraID: String = ""

    private var lang: ResolvedLanguage { languageStore.resolved }

    init(
        cameraManager: CameraManager,
        recorder: VideoRecorder,
        notificationManager: Binding<NotificationManager>,
        storageURL: Binding<URL>,
        languageStore: LanguageStore,
        keepDisplayAwake: Binding<Bool>
    ) {
        self.cameraManager = cameraManager
        self.recorder = recorder
        self._notificationManager = notificationManager
        self._storageURL = storageURL
        self.languageStore = languageStore
        self._keepDisplayAwake = keepDisplayAwake
        self._notifSettings = State(initialValue: notificationManager.wrappedValue.settings)
        self._sensitivity = State(initialValue: recorder.sensitivity)
        self._keepDisplayAwakeDraft = State(initialValue: keepDisplayAwake.wrappedValue)
    }

    var body: some View {
        Form {
            Section(L10n.t(.language, lang)) {
                Picker(L10n.t(.language, lang), selection: $languageStore.selection) {
                    Text(L10n.t(.languageSystem, lang)).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("Русский").tag(AppLanguage.russian)
                }
            }

            // Camera
            Section(L10n.t(.camera, lang)) {
                Picker(L10n.t(.device, lang), selection: $selectedCameraID) {
                    ForEach(cameraManager.availableCameras, id: \.uniqueID) { cam in
                        Text(cam.localizedName).tag(cam.uniqueID)
                    }
                }
                .onChange(of: selectedCameraID) { _, id in
                    let activeID = cameraManager.session.inputs
                        .compactMap { ($0 as? AVCaptureDeviceInput)?.device.uniqueID }
                        .first
                    guard let cam = cameraManager.availableCameras.first(where: { $0.uniqueID == id }) else {
                        return
                    }
                    let shouldRestart = cam.uniqueID != activeID
                    cameraManager.selectedCamera = cam
                    if shouldRestart {
                        cameraManager.startSession(with: cam)
                    }
                }

                Button(L10n.t(.refreshCameras, lang)) {
                    cameraManager.refreshCameras()
                }
            }

            // Storage
            Section(L10n.t(.storage, lang)) {
                HStack {
                    Text(storageURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.t(.chooseEllipsis, lang)) { pickFolder() }
                }
            }

            Section(L10n.t(.display, lang)) {
                Toggle(L10n.t(.keepDisplayAwake, lang), isOn: $keepDisplayAwakeDraft)
            }

            // Motion detection
            Section(L10n.t(.motionDetection, lang)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(.sensitivity(Int(sensitivity * 100)), lang))
                    Slider(value: $sensitivity, in: 0...1)
                }
            }

            // Telegram
            Section("Telegram") {
                Toggle(L10n.t(.enableNotifications, lang), isOn: $notifSettings.telegramEnabled)
                if notifSettings.telegramEnabled {
                    TextField("Bot Token", text: $notifSettings.telegramToken)
                    TextField("Chat ID", text: $notifSettings.telegramChatID)
                }
            }

            // Email
            Section("Email") {
                Toggle(L10n.t(.enableNotifications, lang), isOn: $notifSettings.emailEnabled)
                if notifSettings.emailEnabled {
                    TextField(L10n.t(.smtpHost, lang), text: $notifSettings.emailSMTPHost)
                    TextField(L10n.t(.senderAddress, lang), text: $notifSettings.emailUser)
                    SecureField(L10n.t(.password, lang), text: $notifSettings.emailPassword)
                    TextField(L10n.t(.recipient, lang), text: $notifSettings.emailRecipient)
                }
            }

            HStack {
                Spacer()
                Button(L10n.t(.cancel, lang)) { dismiss() }
                Button(L10n.t(.save, lang)) { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
        .onAppear {
            selectedCameraID = cameraManager.selectedCamera?.uniqueID ?? ""
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.t(.choose, lang)
        if panel.runModal() == .OK, let url = panel.url {
            storageURL = url
        }
    }

    private func save() {
        recorder.sensitivity = sensitivity
        recorder.storageURL = storageURL
        notificationManager.settings = notifSettings
        keepDisplayAwake = keepDisplayAwakeDraft
        dismiss()
    }
}
