import Foundation
import AppKit
import Combine

struct AvailableUpdate: Equatable {
    let version: String
    let pageURL: URL
    let downloadURL: URL?
}

enum UpdateState: Equatable {
    case idle
    case checking
    case unavailable
    case upToDate
    case available(AvailableUpdate)
    case failed(String)
}

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    // Fill this with the GitHub Releases URL when the repository is published.
    private let releasePageURL: URL? = nil
    @Published private(set) var state: UpdateState = .idle

    private init() {}

    func checkForUpdates() {
        guard let releasePageURL else {
            state = .unavailable
            return
        }

        state = .checking
        let apiURL = githubAPIURL(from: releasePageURL) ?? releasePageURL
        URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.state = .failed(error.localizedDescription)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else {
                    self.state = .failed("Invalid update response")
                    return
                }
                let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let download = (json["assets"] as? [[String: Any]])?.first.flatMap { $0["browser_download_url"] as? String }.flatMap(URL.init(string:))
                if Self.isNewer(version, than: Self.currentVersion) {
                    self.state = .available(AvailableUpdate(version: version, pageURL: page, downloadURL: download))
                } else {
                    self.state = .upToDate
                }
            }
        }.resume()
    }

    func openUpdate(_ update: AvailableUpdate) {
        NSWorkspace.shared.open(update.downloadURL ?? update.pageURL)
    }

    private static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r != l { return r > l }
        }
        return false
    }

    private func githubAPIURL(from pageURL: URL) -> URL? {
        let parts = pageURL.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, pageURL.host == "github.com" else { return nil }
        return URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/releases/latest")
    }
}
