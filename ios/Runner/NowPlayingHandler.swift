import Foundation
import MediaPlayer
import UIKit

/// Handles the iOS Now Playing info center and remote-control commands.
///
/// Called from AppDelegate via a Flutter MethodChannel
/// ("com.wiseapps.wisetv/nowplaying").
///
/// Dart call: NowPlayingService.update(title, subtitle, artworkUrl)
/// Dart call: NowPlayingService.clear()
final class NowPlayingHandler: NSObject {

    static let shared = NowPlayingHandler()

    private let channel = "com.wiseapps.wisetv/nowplaying"

    // Cache the last artwork URL to avoid redundant downloads.
    private var lastArtworkUrl: String?

    private override init() { super.init() }

    // ── Registration ─────────────────────────────────────────────────────────

    func register(with flutterViewController: FlutterViewController) {
        let messenger = flutterViewController.binaryMessenger
        let ch = FlutterMethodChannel(name: channel, binaryMessenger: messenger)
        ch.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterMethodNotImplemented); return }
            switch call.method {
            case "update":
                let args = call.arguments as? [String: Any?] ?? [:]
                let title      = args["title"]    as? String ?? ""
                let subtitle   = args["subtitle"] as? String ?? ""
                let artworkUrl = args["artwork"]  as? String
                self.update(title: title, subtitle: subtitle, artworkUrl: artworkUrl)
                result(nil)
            case "clear":
                self.clear()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    func update(title: String, subtitle: String, artworkUrl: String?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:              title,
            MPMediaItemPropertyArtist:            subtitle,
            MPNowPlayingInfoPropertyIsLiveStream:  true,
            MPNowPlayingInfoPropertyPlaybackRate:  1.0,
            MPMediaItemPropertyMediaType:          MPMediaType.tvShow.rawValue,
        ]

        // Reuse cached artwork or fetch a new one
        if let url = artworkUrl, !url.isEmpty {
            if url != lastArtworkUrl {
                lastArtworkUrl = url
                fetchArtwork(from: url) { artwork in
                    if let artwork {
                        var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        updated[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            }
            // Publish without artwork first; artwork update arrives asynchronously.
        } else {
            lastArtworkUrl = nil
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        lastArtworkUrl = nil
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func fetchArtwork(from urlString: String, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async { completion(artwork) }
        }.resume()
    }
}
