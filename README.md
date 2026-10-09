# VideoSecurity

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-F05138" alt="Swift 6" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon-black" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/codec-H.265%20%7C%20HEVC-orange" alt="H.265 HEVC" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

Native macOS motion-detection surveillance app. Capture camera video, detect motion with Accelerate (vDSP), record HEVC clips with a 10-second pre-buffer, and send Telegram or email alerts.

## Features

- **Live camera preview** with continuous or motion-only recording
- **Motion detection** via frame differencing (Accelerate / ARM NEON)
- **Pre-record buffer** — about 10 seconds before motion (30 fps × 300 frames)
- **Post-motion recording** — continues for a short period after the last motion event
- **H.265 (HEVC)** hardware encoding on Apple Silicon
- **Alerts** — Telegram Bot API and/or email (SMTP via system `curl`)
- **Settings** — camera device, storage folder, sensitivity, language (System / English / Russian), keep display awake
- **Sleep prevention** while recording (IOKit `IOPMAssertion`)

## Requirements

| Item | Detail |
|------|--------|
| OS | macOS 14 or later |
| Hardware | Apple Silicon recommended (HEVC hardware encode) |
| Tools | Xcode (open `Package.swift`) |
| Permissions | Camera, Microphone, network (alerts), user-selected folder |

## Build & Run

1. Open `Package.swift` in Xcode (**File → Open**).
2. In **Signing & Capabilities**, use entitlements from `Sources/VideoSecurity/VideoSecurity.entitlements` (camera, microphone, network client, user-selected files).
3. Build and Run (**⌘R**).

On first launch, macOS will ask for camera and microphone access.

## Usage

1. Choose **Continuous** or **Motion** mode on the main screen.
2. Press **Record** (⌘R) to start; **Stop** (⌘.) to finish.
3. Open **Settings** (gear) to pick a camera, storage folder, motion sensitivity, language, and notification credentials.

### Telegram alerts

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy the bot token.
2. Get your chat ID (for example via `@userinfobot` or the Bot API `getUpdates`).
3. In Settings → Telegram: enable notifications, paste **Bot Token** and **Chat ID**, then Save.

### Email alerts

In Settings → Email: enable notifications and set SMTP host (default `smtp.gmail.com`), sender address, password, and recipient. Messages are sent with `/usr/bin/curl` over SMTP — no third-party mail libraries.

## Project structure

```
Sources/VideoSecurity/
├── VideoSecurityApp.swift      # @main
├── Info.plist
├── VideoSecurity.entitlements
├── Views/
│   ├── ContentView.swift       # Main screen
│   ├── CameraPreviewView.swift # AVCaptureVideoPreviewLayer
│   └── SettingsView.swift      # Settings
├── Managers/
│   ├── CameraManager.swift     # AVCaptureSession
│   ├── MotionDetector.swift    # vDSP frame diff
│   ├── VideoRecorder.swift     # AVAssetWriter + pre-buffer
│   └── NotificationManager.swift # Telegram + Email
└── Utils/
    ├── CircularFrameBuffer.swift # 10-second ring buffer
    ├── SleepPreventer.swift      # IOPMAssertion
    └── LanguageStore.swift       # EN / RU / System
```

## Tech stack

| Area | Technology |
|------|------------|
| UI | Swift 6 + SwiftUI |
| Capture / record | AVFoundation, AVAssetWriter |
| Motion | Accelerate (vDSP / vImage) |
| Encode | H.265 (HEVC) |
| Sleep | IOKit (`IOPMAssertion`) |
| Alerts | URLSession (Telegram), system `curl` (email) |

## License

This project is licensed under the [MIT License](LICENSE).
