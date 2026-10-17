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
