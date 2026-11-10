import CoreGraphics

/// Dominant colour of an image (SPEC §5.4): downscale to 40×40, k-means with k = 5,
/// prefer the largest cluster that is neither grey nor too dark/bright, else the average.
enum ColorExtractor {
    static func dominantColor(of image: CGImage) -> RGBColor? {
        let side = 40
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let ok = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard ok else { return nil }

        var points: [SIMD3<Double>] = []
        points.reserveCapacity(side * side)
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 128 {
            points.append(SIMD3(Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])) / 255)
        }
        guard !points.isEmpty else { return nil }
        let average = points.reduce(SIMD3<Double>(repeating: 0), +) / Double(points.count)

        // k-means, deterministic start (evenly spaced samples)
        let k = min(5, points.count)
        var centers = (0..<k).map { points[$0 * points.count / k] }
        var assignment = [Int](repeating: 0, count: points.count)
        for _ in 0..<12 {
            for (i, p) in points.enumerated() {
                var best = 0
                var bestD = Double.infinity
                for (j, c) in centers.enumerated() {
                    let d = p - c
                    let dist = (d * d).sum()
                    if dist < bestD { bestD = dist; best = j }
                }
                assignment[i] = best
            }
            var sums = [SIMD3<Double>](repeating: .zero, count: k)
            var counts = [Int](repeating: 0, count: k)
            for (i, p) in points.enumerated() {
                sums[assignment[i]] += p
                counts[assignment[i]] += 1
            }
            for j in 0..<k where counts[j] > 0 { centers[j] = sums[j] / Double(counts[j]) }
        }
        var counts = [Int](repeating: 0, count: k)
        assignment.forEach { counts[$0] += 1 }

        let ranked = (0..<k).sorted { counts[$0] > counts[$1] }
        for j in ranked where counts[j] > 0 {
            let c = RGBColor(r: centers[j].x, g: centers[j].y, b: centers[j].z)
            if c.saturation > 0.2 && c.brightness >= 0.15 && c.brightness <= 0.9 { return c }
        }
        return RGBColor(r: average.x, g: average.y, b: average.z)
    }
}
