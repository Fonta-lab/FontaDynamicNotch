import Foundation
import ImageIO

struct ArtworkResult: @unchecked Sendable {   // CGImage is immutable
    let image: CGImage
    let color: RGBColor?
}

/// Downloads and decodes cover art off the main thread. Keeps the last 20 tracks in memory.
actor ArtworkLoader {
    static let shared = ArtworkLoader()

    private var cache: [String: ArtworkResult] = [:]
    private var order: [String] = []
    private let limit = 20

    func load(id: String, url: URL) async -> ArtworkResult? {
        if let hit = cache[id] {
            touch(id)
            return hit
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode ?? 200 == 200,
              let result = Self.decode(data) else { return nil }
        cache[id] = result
        touch(id)
        while order.count > limit { cache[order.removeFirst()] = nil }
        return result
    }

    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    private static func decode(_ data: Data) -> ArtworkResult? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return ArtworkResult(image: img, color: ColorExtractor.dominantColor(of: img))
    }
}
