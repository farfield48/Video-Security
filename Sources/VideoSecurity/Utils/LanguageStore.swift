import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case russian
}

enum ResolvedLanguage {
    case english
    case russian
}

final class LanguageStore: ObservableObject {
    private static let defaultsKey = "appLanguage"

    @Published var selection: AppLanguage {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.defaultsKey)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let value = AppLanguage(rawValue: raw) {
            selection = value
        } else {
            selection = .system
        }
    }

    var resolved: ResolvedLanguage {
        switch selection {
        case .system:
            return Self.systemIsRussian() ? .russian : .english
        case .english:
            return .english
        case .russian:
            return .russian
        }
    }

    static func systemIsRussian() -> Bool {
        guard let first = Locale.preferredLanguages.first else { return false }
        let code = first.split(whereSeparator: { $0 == "-" || $0 == "_" }).first
        return code == "ru"
    }
}

enum L10n {
    static func t(_ key: Key, _ lang: ResolvedLanguage) -> String {
        switch lang {
        case .english:
            return key.english
        case .russian:
            return key.russian
        }
    }

    enum Key {
        case motionBanner
        case mode
        case continuous
        case motionMode
        case record
        case stop
        case ready
        case recording
        case waitingForMotion
        case stopped
        case motionRecording
        case camera
        case device
        case refreshCameras
        case storage
        case chooseEllipsis
        case motionDetection
        case sensitivity(Int)
        case enableNotifications
        case smtpHost
        case senderAddress
        case password
        case recipient
        case cancel
        case save
        case choose
        case language
        case languageSystem
        case display
        case keepDisplayAwake

        var english: String {
            switch self {
            case .motionBanner: return "Motion!"
            case .mode: return "Mode"
            case .continuous: return "Continuous"
            case .motionMode: return "Motion"
            case .record: return "Record"
            case .stop: return "Stop"
            case .ready: return "Ready"
            case .recording: return "Recording…"
            case .waitingForMotion: return "Waiting for motion…"
            case .stopped: return "Stopped"
            case .motionRecording: return "Motion! Recording…"
            case .camera: return "Camera"
            case .device: return "Device"
            case .refreshCameras: return "Refresh camera list"
            case .storage: return "Storage"
            case .chooseEllipsis: return "Choose…"
            case .motionDetection: return "Motion detection"
            case .sensitivity(let value): return "Sensitivity: \(value)%"
            case .enableNotifications: return "Enable notifications"
            case .smtpHost: return "SMTP host"
            case .senderAddress: return "Sender address"
            case .password: return "Password / App Password"
            case .recipient: return "Recipient"
            case .cancel: return "Cancel"
            case .save: return "Save"
            case .choose: return "Choose"
            case .language: return "Language"
            case .languageSystem: return "System"
            case .display: return "Display"
            case .keepDisplayAwake: return "Keep display awake"
            }
        }

        var russian: String {
            switch self {
            case .motionBanner: return "Движение!"
            case .mode: return "Режим"
            case .continuous: return "Непрерывная"
            case .motionMode: return "По движению"
            case .record: return "Запись"
            case .stop: return "Стоп"
            case .ready: return "Готово"
            case .recording: return "Запись…"
            case .waitingForMotion: return "Ожидание движения…"
            case .stopped: return "Остановлено"
            case .motionRecording: return "Движение! Запись…"
            case .camera: return "Камера"
            case .device: return "Устройство"
            case .refreshCameras: return "Обновить список камер"
            case .storage: return "Хранилище"
            case .chooseEllipsis: return "Выбрать…"
            case .motionDetection: return "Детекция движения"
            case .sensitivity(let value): return "Чувствительность: \(value)%"
            case .enableNotifications: return "Включить уведомления"
            case .smtpHost: return "SMTP хост"
            case .senderAddress: return "Адрес отправителя"
            case .password: return "Пароль / App Password"
            case .recipient: return "Получатель"
            case .cancel: return "Отмена"
            case .save: return "Сохранить"
            case .choose: return "Выбрать"
            case .language: return "Язык"
            case .languageSystem: return "Системный"
            case .display: return "Дисплей"
            case .keepDisplayAwake: return "Не выключать дисплей"
            }
        }
    }
}
