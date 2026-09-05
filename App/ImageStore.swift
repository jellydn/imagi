import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import StudioCore

actor ImageStore {
    static let shared = ImageStore()
    private nonisolated let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "ImageStudio/Images", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    nonisolated func url(for filename: String) -> URL { directory.appending(path: filename) }

    func read(_ filename: String) throws -> Data { try Data(contentsOf: url(for: filename)) }

    func save(_ images: [Data], cropTo ratio: AspectRatio?) throws -> [String] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var names: [String] = []
        do {
            for data in images {
                try Task.checkCancellation()
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw StudioError.invalidResponse
                }
                let image = try cropped(original, to: ratio)
                let name = UUID().uuidString + ".png"
                names.append(name)
                try png(image).write(to: url(for: name), options: .atomic)
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 640,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                let saved = try read(name)
                guard let thumbnailSource = CGImageSourceCreateWithData(saved as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(thumbnailSource, 0, options as CFDictionary) else {
                    throw StudioError.invalidResponse
                }
                try png(thumbnail).write(to: url(for: name + ".thumb.png"), options: .atomic)
            }
            return names
        } catch {
            for name in names { try? remove(name) }
            throw error
        }
    }

    func remove(_ filename: String) throws {
        for name in [filename, filename + ".thumb.png"] {
            let path = url(for: name)
            if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
        }
    }

    func byteCount() throws -> Int64 {
        guard FileManager.default.fileExists(atPath: directory.path) else { return 0 }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { total, url in total + Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }

    private func cropped(_ image: CGImage, to ratio: AspectRatio?) throws -> CGImage {
        guard let ratio else { return image }
        let width = Double(image.width), height = Double(image.height)
        let targetWidth = min(width, height * ratio.value)
        let targetHeight = min(height, width / ratio.value)
        let rect = CGRect(x: floor((width - targetWidth) / 2), y: floor((height - targetHeight) / 2),
                          width: floor(targetWidth), height: floor(targetHeight))
        guard let cropped = image.cropping(to: rect) else { throw StudioError.invalidResponse }
        return cropped
    }

    private func png(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            throw StudioError.invalidResponse
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw StudioError.invalidResponse }
        return data as Data
    }
}
