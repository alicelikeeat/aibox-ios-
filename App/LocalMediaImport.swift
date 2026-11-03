import Foundation
import UniformTypeIdentifiers
import ImageIO
import AVFoundation

/// Copies provider URLs while they are still valid, without loading the full movie into memory.
enum LocalMediaImport {
    enum Kind { case image, gif, video }
    enum Failure: LocalizedError {
        case tooLarge(Int), unsupported, unreadable, tooManyFrames
        var errorDescription: String? {
            switch self {
            case .tooLarge(let limit): return "媒体超过 \(limit / 1024 / 1024) MiB 上限，请选择更小的文件。"
            case .tooManyFrames: return "GIF 最多支持 300 帧，请缩短动画后重试。"
            case .unsupported: return "媒体格式不匹配或无法解码，请选择图片、GIF 或可播放的视频。"
            case .unreadable: return "无法读取媒体文件，请先在相册或文件 App 中完成下载后重试。"
            }
        }
    }
    static func copy(_ url: URL, into root: URL, kind: Kind, limit: Int? = nil) throws -> URL {
        let maximum = limit ?? (kind == .video ? 256 : 32) * 1024 * 1024
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let folder = root.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? (kind == .video ? "mov" : kind == .gif ? "gif" : "img") : url.pathExtension.lowercased()
        let destination = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        var coordinationError: NSError?
        var outcome: Result<Void, Error> = .failure(Failure.unreadable)
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
            outcome = Result {
                guard let input = InputStream(url: readable), let output = OutputStream(url: destination, append: false) else { throw Failure.unreadable }
                input.open(); output.open()
                defer { input.close(); output.close() }
                var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                var total = 0
                while true {
                    let count = input.read(&buffer, maxLength: buffer.count)
                    guard count >= 0 else { throw input.streamError ?? Failure.unreadable }
                    if count == 0 { break }
                    total += count
                    guard total <= maximum else { throw Failure.tooLarge(maximum) }
                    try buffer.withUnsafeBufferPointer { bytes in
                        var offset = 0
                        while offset < count {
                            let written = output.write(bytes.baseAddress!.advanced(by: offset), maxLength: count - offset)
                            guard written > 0 else { throw output.streamError ?? Failure.unreadable }
                            offset += written
                        }
                    }
                }
                guard total > 0 else { throw Failure.unreadable }
            }
        }
        do {
            if let coordinationError { throw coordinationError }
            try outcome.get()
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
    static func validate(_ url: URL, kind: Kind) async throws {
        if kind == .video {
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard playable, !tracks.isEmpty else { throw Failure.unsupported }
        } else {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0,
                  let type = CGImageSourceGetType(source),
                  kind != .gif || UTType(type as String)?.conforms(to: .gif) == true,
                  CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 64] as CFDictionary) != nil else { throw Failure.unsupported }
            if kind == .gif, CGImageSourceGetCount(source) > 300 {
                throw Failure.tooManyFrames
            }
        }
    }
}
