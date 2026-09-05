import XCTest
import SwiftData
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import StudioCore

final class LocalLibraryTests: XCTestCase {
    @MainActor
    func testHistoryFavoritesAndRefinementSurviveContextReload() throws {
        let schema = Schema([GenerationRecord.self, ImageAsset.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let options = GenerationOptions(provider: .xAI, count: 4, ratio: .story)
        let original = GenerationRecord(prompt: "Original", options: options, parentImageID: nil)
        context.insert(original)
        let image = ImageAsset(filename: "original.png", index: 1, generation: original)
        image.isFavorite = true
        context.insert(image)
        let refinement = GenerationRecord(prompt: "Make it red", options: options, parentImageID: image.id)
        context.insert(refinement)
        let child = ImageAsset(filename: "child.png", index: 0, generation: refinement)
        context.insert(child)
        try context.save()

        let reloaded = ModelContext(container)
        let records = try reloaded.fetch(FetchDescriptor<GenerationRecord>())
        XCTAssertEqual(records.count, 2)
        let loadedOriginal = try XCTUnwrap(records.first { $0.id == original.id })
        XCTAssertEqual(loadedOriginal.images.count, 1)
        XCTAssertEqual(loadedOriginal.options, options)
        XCTAssertEqual(loadedOriginal.images.first?.isFavorite, true)
        let loadedRefinement = try XCTUnwrap(records.first { $0.id == refinement.id })
        XCTAssertEqual(loadedRefinement.parentImageID, image.id)
        XCTAssertEqual(loadedRefinement.images.first?.filename, "child.png")

        // Explicit deletion leaves descendants and their metadata intact.
        reloaded.delete(try XCTUnwrap(loadedOriginal.images.first))
        try reloaded.save()
        XCTAssertEqual(loadedRefinement.images.count, 1)
        XCTAssertEqual(try reloaded.fetchCount(FetchDescriptor<ImageAsset>()), 1)
    }

    func testPNGStorageCropThumbnailAndRemoval() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(directory: directory)
        let input = try makePNG(width: 1200, height: 800)
        for ratio in AspectRatio.allCases {
            let names = try await store.save([input], cropTo: ratio)
            let name = try XCTUnwrap(names.first)
            let bytes = try await store.read(name)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(Double(image.width) / Double(image.height), ratio.value, accuracy: 0.003)
            let thumbnailData = try await store.read(name + ".thumb.png")
            let thumbnailSource = try XCTUnwrap(CGImageSourceCreateWithData(thumbnailData as CFData, nil))
            let thumbnail = try XCTUnwrap(CGImageSourceCreateImageAtIndex(thumbnailSource, 0, nil))
            XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 640)
            try await store.remove(name)
        }
        let remaining = try await store.byteCount()
        XCTAssertEqual(remaining, 0)
    }

    func testInvalidBatchLeavesNoPartialFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImageStore(directory: directory)
        do {
            _ = try await store.save([makePNG(width: 20, height: 20), Data("broken image".utf8)], cropTo: nil)
            XCTFail("Expected image validation failure")
        } catch { XCTAssertTrue(error is StudioError) }
        let remaining = try await store.byteCount()
        XCTAssertEqual(remaining, 0)
    }

    private func makePNG(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
