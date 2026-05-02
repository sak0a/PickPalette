import AppKit

struct GitHubRelease: Decodable {
    let tag_name: String
    let name: String
    let body: String
    let html_url: String
}

final class UpdateChecker {
    private static let lastCheckKey = "UpdateChecker_lastCheck"
    private static let lastNotifiedVersionKey = "UpdateChecker_lastNotifiedVersion"
    private static let cooldown: TimeInterval = 6 * 60 * 60
    private static let repo = "sak0a/PickPalette"

    static func checkForUpdates(manual: Bool = false) {
        if !manual {
            let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
            if Date().timeIntervalSince1970 - lastCheck < cooldown { return }
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                if manual { DispatchQueue.main.async { showAlert(messageText: "Check Failed", informativeText: "Unable to check for updates. Please check your internet connection.", style: .warning) } }
                return
            }

            let latestVersion = stripV(release.tag_name)
            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

            if compareVersions(latestVersion, currentVersion) > 0 {
                let lastNotified = UserDefaults.standard.string(forKey: lastNotifiedVersionKey)
                if lastNotified == latestVersion && !manual { return }
                UserDefaults.standard.set(latestVersion, forKey: lastNotifiedVersionKey)

                DispatchQueue.main.async {
                    showUpdateAlert(release: release, currentVersion: currentVersion)
                }
            } else if manual {
                DispatchQueue.main.async {
                    showAlert(messageText: "You're Up to Date", informativeText: "PickPalette \(currentVersion) is the latest version.", style: .informational)
                }
            }
        }.resume()
    }

    // MARK: - Private

    private static func stripV(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func compareVersions(_ a: String, _ b: String) -> Int {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(aParts.count, bParts.count)
        for i in 0..<maxLen {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal != bVal { return aVal - bVal }
        }
        return 0
    }

    private static func showUpdateAlert(release: GitHubRelease, currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        let title = release.name.isEmpty ? release.tag_name : release.name
        alert.informativeText = "PickPalette \(title) is available (you have \(currentVersion)).\n\n\(release.body)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: release.html_url) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func showAlert(messageText: String, informativeText: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
