import Foundation

struct NotificationSettings {
    var telegramEnabled = false
    var telegramToken = ""
    var telegramChatID = ""

    var emailEnabled = false
    var emailSMTPHost = "smtp.gmail.com"
    var emailSMTPPort = 587
    var emailUser = ""
    var emailPassword = ""
    var emailRecipient = ""
}

final class NotificationManager {
    var settings = NotificationSettings()

    func sendMotionAlert(at date: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let text = "Motion detected: \(formatter.string(from: date))"

        if settings.telegramEnabled {
            sendTelegram(text: text)
        }
        if settings.emailEnabled {
            sendEmail(subject: "VideoSecurity: motion detected", body: text)
        }
    }

    // MARK: - Telegram

    private func sendTelegram(text: String) {
        guard !settings.telegramToken.isEmpty, !settings.telegramChatID.isEmpty else { return }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.telegram.org"
        components.path = "/bot\(settings.telegramToken)/sendMessage"

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "chat_id": settings.telegramChatID,
            "text": text
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Email (SMTP via curl)

    private func sendEmail(subject: String, body: String) {
        guard !settings.emailUser.isEmpty,
              !settings.emailPassword.isEmpty,
              !settings.emailRecipient.isEmpty else { return }

        // Use system curl via Process — no third-party libraries required
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")

        let from = settings.emailUser
        let to = settings.emailRecipient
        let host = settings.emailSMTPHost
        let port = settings.emailSMTPPort
        let user = settings.emailUser
        let pass = settings.emailPassword

        let rawMessage = """
        From: \(from)
        To: \(to)
        Subject: \(subject)
        Content-Type: text/plain; charset=UTF-8

        \(body)
        """

        // Write the message to a temporary file
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vs_mail_\(UUID().uuidString).txt")
        try? rawMessage.data(using: .utf8)?.write(to: tmpURL)

        process.arguments = [
            "--url", "smtps://\(host):\(port)",
            "--ssl-reqd",
            "--mail-from", from,
            "--mail-rcpt", to,
            "--user", "\(user):\(pass)",
            "--upload-file", tmpURL.path,
            "--silent"
        ]

        process.terminationHandler = { _ in
            try? FileManager.default.removeItem(at: tmpURL)
        }

        try? process.run()
    }
}
