import XCTest
import UIKit
import AVFoundation
import UniformTypeIdentifiers

final class MediaImportTests: XCTestCase {
    func testImageAndGIFCopySurviveProviderFileRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("source.gif")
        // A real one-pixel GIF, rather than bytes with a misleading extension.
        let gif = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!
        try gif.write(to: source)
        let copied = try LocalMediaImport.copy(source, into: root, kind: .gif)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try Data(contentsOf: copied), gif)
        try await LocalMediaImport.validate(copied, kind: .gif)
        try await LocalMediaImport.validate(copied, kind: .image)
    }

    func testLargeAndMismatchedFilesAreRejectedWithoutPartialCopies() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("bad.mov")
        try Data(repeating: 1, count: 100).write(to: source)
        XCTAssertThrowsError(try LocalMediaImport.copy(source, into: root, kind: .video, limit: 50))
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Media").path)
        XCTAssertTrue(files.isEmpty)
        do { try await LocalMediaImport.validate(source, kind: .video); XCTFail("Invalid video accepted") } catch { }
        do { try await LocalMediaImport.validate(source, kind: .image); XCTFail("Invalid image accepted") } catch { }
    }

    func testVideoCopyAndPlaybackValidation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("sample.mov")
        let writer = try AVAssetWriter(outputURL: source, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 16, AVVideoHeightKey: 16])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 16, kCVPixelBufferHeightKey as String: 16])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32ARGB, nil, &buffer), kCVReturnSuccess)
        let pixel = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixel, [])
        if let address = CVPixelBufferGetBaseAddress(pixel) { memset(address, 0, CVPixelBufferGetDataSize(pixel)) }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        for frame in 0..<3 {
            let deadline = Date().addingTimeInterval(30)
            while !input.isReadyForMoreMediaData && writer.status == .writing && Date() < deadline {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            guard input.isReadyForMoreMediaData else {
                throw writer.error ?? NSError(domain: "MediaFixture", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Video encoder did not become ready; status \(writer.status.rawValue)"])
            }
            XCTAssertTrue(adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let copied = try LocalMediaImport.copy(source, into: root, kind: .video)
        try FileManager.default.removeItem(at: source)
        try await LocalMediaImport.validate(copied, kind: .video)
        do { try await LocalMediaImport.validate(copied, kind: .gif); XCTFail("Video accepted as GIF") } catch { }
    }
}
