import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AiBoxCore

@MainActor
final class SandboxModel: ObservableObject {
    @Published private(set) var editor = try! WorldEditor()
    @Published private(set) var preview: AiBoxWorld?
    @Published private(set) var pending: WorldEdit?
    @Published var selected = GridPosition(x: 128, z: 128)
    @Published var tool = "方块"
    @Published var value = "AiBox"
    @Published var importedAsset: String?
    @Published var status = "正在读取存档…"
    @Published var error: String?
    @Published var busy = true
    @Published var loadFailed = false
    @Published var playing = false
    @Published var joystick = SIMD2<Float>.zero
    @Published var player = SIMD3<Float>(128.5, 0, 130.5)
    @Published var yaw: Float = 0
    @Published var distance: Float = 14
    @Published var focus = SIMD3<Float>(128.5, 0, 128.5)
    static let tools = ["方块", "擦除", "图片", "GIF", "视频", "文字", "数字", "图标"]
    let root: URL
    private let store: AiBoxWorldStore

    init() {
        var folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiBox", isDirectory: true)
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--uitest-world"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString: arguments[index + 1]) {
            folder = folder.appendingPathComponent("UITests-" + id.uuidString, isDirectory: true)
        }
        #endif
        root = folder
        store = AiBoxWorldStore(fileURL: root.appendingPathComponent("world.json"))
    }

    var shownWorld: AiBoxWorld { preview ?? editor.world }
    var canEdit: Bool { !busy && !loadFailed && !playing }

    func load() async {
        do {
            if let world = try await store.load() { editor = try WorldEditor(world: world) }
            status = "点击格子选择，预览后确认；双指拖动平移"
        } catch {
            loadFailed = true
            self.error = "存档读取失败，原文件已保留：\(error.localizedDescription)"
            status = "读取失败：已禁止覆盖存档"
        }
        busy = false
    }

    func draft() {
        guard canEdit else { return }
        do {
            var operations: [WorldEdit.Operation] = editor.world.objects
                .filter { $0.anchor == selected }.map { .remove($0.id) }
            if tool != "擦除" {
                let kind: MediaKind? = ["图片": .image, "GIF": .gif, "视频": .video,
                                        "文字": .text, "数字": .number, "图标": .icon][tool]
                var reference: MediaReference?
                if let kind {
                    let content: String
                    if [.image, .gif, .video].contains(kind) {
                        guard let importedAsset else { throw SandboxError.message("请先导入对应媒体文件。") }
                        content = importedAsset
                    } else {
                        content = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !content.isEmpty, content.count <= 64 else {
                            throw SandboxError.message("内容需为 1–64 个字符。")
                        }
                        if kind == .number, content.range(of: #"^-?[0-9]{1,12}(\.[0-9]{1,6})?$"#, options: .regularExpression) == nil {
                            throw SandboxError.message("请输入有效数字，最多 12 位整数和 6 位小数。")
                        }
                        if kind == .icon, UIImage(systemName: content) == nil {
                            throw SandboxError.message("请输入有效 SF Symbol 名称，例如 star.fill。")
                        }
                    }
                    reference = .init(assetID: content, kind: kind)
                }
                if abs(Float(selected.x) + 0.5 - player.x) < 0.8 && abs(Float(selected.z) + 0.5 - player.z) < 0.8 {
                    throw SandboxError.message("不能在角色所在位置放置方块。")
                }
                operations.append(.place(.init(anchor: selected,
                    transform: .init(x: Double(selected.x) + 0.5, z: Double(selected.z) + 0.5), media: reference)))
            }
            guard !operations.isEmpty else { throw SandboxError.message("该格子没有可擦除的对象。") }
            let edit = WorldEdit(operations: operations)
            preview = try editor.preview(edit)
            pending = edit
            status = "橙色为待确认格子，尚未写入世界"
        } catch { self.error = error.localizedDescription }
    }

    func confirm() {
        guard let pending, let preview else { return }
        do {
            try editor.commit(pending, expectedPreview: preview)
            cancel()
            status = "已确认，尚未保存"
        } catch { self.error = error.localizedDescription }
    }
    func cancel() { pending = nil; preview = nil }
    func undo() { cancel(); if editor.undo() { status = "已撤销，尚未保存" } }
    func redo() { cancel(); if editor.redo() { status = "已重做，尚未保存" } }
    func save() async {
        guard !busy, !loadFailed, pending == nil else { return }
        busy = true
        do { try await store.save(editor.world); status = "已保存" }
        catch { self.error = "保存失败：\(error.localizedDescription)" }
        busy = false
    }

    var importKind: LocalMediaImport.Kind { tool == "视频" ? .video : tool == "GIF" ? .gif : .image }

    func beginImport() {
        busy = true
        status = "正在读取媒体，云端文件可能需要下载…"
        cancel()
    }
    func importFile(_ url: URL) async {
        let kind = importKind, root = root
        beginImport()
        do {
            let local = try await Task.detached { try LocalMediaImport.copy(url, into: root, kind: kind) }.value
            await finishImport(local, kind: kind)
        } catch { failImport(error) }
    }
    func importPhoto(_ provider: NSItemProvider) {
        let kind = importKind, root = root
        let type = kind == .video ? UTType.movie.identifier : UTType.image.identifier
        beginImport()
        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, error in
            // NSItemProvider deletes its temporary URL when this callback returns.
            let copied: Result<URL, Error> = Result {
                if let error { throw error }
                guard let url else { throw LocalMediaImport.Failure.unreadable }
                return try LocalMediaImport.copy(url, into: root, kind: kind)
            }
            Task { @MainActor in
                guard let self else { return }
                switch copied {
                case .success(let local): await self.finishImport(local, kind: kind)
                case .failure(let error): self.failImport(error)
                }
            }
        }
    }
    private func finishImport(_ local: URL, kind: LocalMediaImport.Kind) async {
        do {
            try await LocalMediaImport.validate(local, kind: kind)
            importedAsset = local.lastPathComponent
            status = "媒体已导入，请点击预览编辑，再确认编辑"
            busy = false
        } catch {
            try? FileManager.default.removeItem(at: local)
            failImport(error)
        }
    }
    private func failImport(_ error: Error) {
        busy = false
        status = "导入失败，可重新选择媒体"
        self.error = "导入失败：\(error.localizedDescription)"
    }

    func tick(_ delta: Double) {
        guard playing, !busy, !loadFailed else { return }
        let dt = Float(min(0.05, max(0, delta)))
        let v = joystick
        let dx = (v.x * cos(yaw) + v.y * sin(yaw)) * dt * 4
        let dz = (-v.x * sin(yaw) + v.y * cos(yaw)) * dt * 4
        let p = WorldNavigation.move(x: Double(player.x), z: Double(player.z), dx: Double(dx), dz: Double(dz), world: editor.world)
        player = SIMD3(Float(p.x), 0, Float(p.z))
        focus = player
    }
}

enum SandboxError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
