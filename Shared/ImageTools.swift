import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

nonisolated enum ImageTools {
    /// Decodes any image format and re-encodes it as a JPEG whose longest side is at most
    /// `maxPixelSize`. Uses ImageIO's thumbnailer, which never decodes the full-size image,
    /// so it's light on memory (important in the share extension).
    static func jpeg(from data: Data, maxPixelSize: Int, quality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // respect camera rotation
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// A short "visual fingerprint" of an image (a 256-bit difference hash). Two copies of the
    /// same photo, even re-compressed or resized, get nearly identical fingerprints.
    static func fingerprint(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let small = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 128,
              ] as CFDictionary) else { return nil }

        // Shrink to 17×16 grayscale, then record whether each pixel is brighter than its right neighbour.
        let width = 17, height = 16
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(small, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var bits: [Bool] = []
        for row in 0..<height {
            for column in 0..<(width - 1) {
                bits.append(pixels[row * width + column] > pixels[row * width + column + 1])
            }
        }
        // Pack 4 bits per hex character.
        return stride(from: 0, to: bits.count, by: 4).map { start in
            let nibble = bits[start..<start + 4].reduce(0) { $0 << 1 | ($1 ? 1 : 0) }
            return String(nibble, radix: 16)
        }.joined()
    }

    /// True when two fingerprints are close enough to be the same photo.
    static func isSamePhoto(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        let differingBits = zip(a, b).reduce(0) { total, pair in
            let x = Int(String(pair.0), radix: 16) ?? 0, y = Int(String(pair.1), radix: 16) ?? 0
            return total + (x ^ y).nonzeroBitCount
        }
        // Out of 256. Re-saved copies of a photo differ by ~10 bits; different photos, even of
        // the same piece from another angle, by 60+.
        return differingBits <= 24
    }
}

extension Image {
    /// Builds a SwiftUI Image from stored photo data, or nil if it can't be decoded.
    init?(photoData: Data?) {
        guard let photoData, let image = PlatformImage(data: photoData) else { return nil }
        #if os(macOS)
        self.init(nsImage: image)
        #else
        self.init(uiImage: image)
        #endif
    }
}
