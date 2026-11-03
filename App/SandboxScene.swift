import SwiftUI
import RealityKit
import Combine
import AVFoundation
import ImageIO
import AiBoxCore

struct SandboxScene: UIViewRepresentable {
    @ObservedObject var model: SandboxModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.install(view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { context.coordinator.refresh() }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor
    final class Coordinator: NSObject {
        let model: SandboxModel
        weak var view: ARView?
        let root = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        let objects = Entity()
        let grid = Entity()
        let marker = ModelEntity(mesh: .generateBox(size: [1.02, 0.025, 1.02]),
                                 materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)])
        let avatar = ModelEntity(mesh: .generateSphere(radius: 0.25),
                                 materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        var subscription: Cancellable?
        var rendered: [WorldObject]?
        var gridCenter: SIMD2<Int>?
        var selected: GridPosition?
        var isPreview = false
        var media: [UUID: CellPlayback] = [:]
        var elapsed = 0.0
        var previousPan = CGPoint.zero
        init(model: SandboxModel) { self.model = model }

        func install(_ view: ARView) {
            self.view = view
            view.environment.background = .color(UIColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1))
            view.scene.addAnchor(root)
            root.addChild(camera); root.addChild(objects); root.addChild(grid)
            root.addChild(marker); root.addChild(avatar)
            let floor = ModelEntity(mesh: .generateBox(size: [256, 0.1, 256]),
                                    materials: [SimpleMaterial(color: UIColor(white: 0.22, alpha: 1), isMetallic: false)])
            floor.position = [128, -0.06, 128]
            root.addChild(floor)
            let sun = DirectionalLight()
            sun.light.intensity = 1800
            sun.look(at: [128, 0, 128], from: [100, 50, 100], relativeTo: nil)
            root.addChild(sun)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap); view.addGestureRecognizer(pan); view.addGestureRecognizer(pinch)
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                // RealityKit scene updates are delivered on the main thread.
                self?.step(event.deltaTime)
            }
            refresh()
        }
        func stop() {
            subscription?.cancel(); subscription = nil
            media.values.forEach { $0.stop() }; media.removeAll()
        }
        func step(_ dt: Double) {
            model.tick(dt)
            elapsed += min(0.05, max(0, dt))
            for state in media.values { state.update(elapsed: elapsed) }
            updateCamera()
        }
        func updateCamera() {
            let f = model.focus
            let d = model.distance
            let position = f + SIMD3(sin(model.yaw) * d, d * 0.85, cos(model.yaw) * d)
            camera.look(at: f, from: position, relativeTo: nil)
            avatar.position = model.player + SIMD3(0, 0.3, 0)
            rebuildGrid()
        }
        func refresh() {
            updateCamera()
            marker.position = [Float(model.selected.x) + 0.5, 0.025, Float(model.selected.z) + 0.5]
            marker.isEnabled = !model.playing
            let world = model.shownWorld
            guard rendered != world.objects || selected != model.selected || isPreview != (model.pending != nil) else { return }
            rendered = world.objects; selected = model.selected; isPreview = model.pending != nil
            objects.children.removeAll()
            media.values.forEach { $0.stop() }; media.removeAll()
            var liveCount = 0
            // Selection first, then distance, as in Moonlight's media scheduling.
            let sorted = world.objects.sorted { a, b in
                if (a.anchor == model.selected) != (b.anchor == model.selected) { return a.anchor == model.selected }
                let da = hypot(a.transform.x - Double(model.focus.x), a.transform.z - Double(model.focus.z))
                let db = hypot(b.transform.x - Double(model.focus.x), b.transform.z - Double(model.focus.z))
                return da == db ? a.id.uuidString < b.id.uuidString : da < db
            }
            for object in sorted {
                let t = object.transform
                let previewed = isPreview && object.anchor == model.selected
                let cube = ModelEntity(mesh: .generateBox(size: 0.96), materials: [SimpleMaterial(
                    color: previewed ? .systemOrange : .systemTeal, isMetallic: false)])
                cube.position = [Float(t.x), Float(t.y + t.scale / 2), Float(t.z)]
                cube.scale = SIMD3(repeating: Float(t.scale))
                cube.orientation = simd_quatf(angle: Float(t.yawRadians), axis: [0, 1, 0])
                if let reference = object.media {
                    let face = ModelEntity(mesh: .generatePlane(width: 0.9, depth: 0.9),
                                           materials: [SimpleMaterial(color: .white, isMetallic: false)])
                    face.position = [0, 0.49, 0]
                    cube.addChild(face)
                    let animated = reference.kind == .gif || reference.kind == .video
                    let live = !animated || liveCount < 2
                    if animated && live { liveCount += 1 }
                    let state = CellPlayback(reference: reference, root: model.root, face: face,
                                             live: live, start: elapsed)
                    state.onError = { [weak model] message in model?.status = message }
                    state.load()
                    media[object.id] = state
                }
                objects.addChild(cube)
            }
        }
        func rebuildGrid() {
            let center = SIMD2(Int(model.focus.x / 16) * 16, Int(model.focus.z / 16) * 16)
            guard center != gridCenter else { return }
            gridCenter = center
            grid.children.removeAll()
            let minX = max(0, center.x - 16), maxX = min(256, center.x + 32)
            let minZ = max(0, center.y - 16), maxZ = min(256, center.y + 32)
            let material = SimpleMaterial(color: UIColor(white: 0.4, alpha: 1), isMetallic: false)
            for x in minX...maxX {
                let line = ModelEntity(mesh: .generateBox(size: [0.015, 0.01, Float(maxZ - minZ)]), materials: [material])
                line.position = [Float(x), 0, Float(minZ + maxZ) / 2]; grid.addChild(line)
            }
            for z in minZ...maxZ {
                let line = ModelEntity(mesh: .generateBox(size: [Float(maxX - minX), 0.01, 0.015]), materials: [material])
                line.position = [Float(minX + maxX) / 2, 0, Float(z)]; grid.addChild(line)
            }
        }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard model.canEdit, let view, let ray = view.ray(through: gesture.location(in: view)), abs(ray.direction.y) > 0.0001 else { return }
            let distance = -ray.origin.y / ray.direction.y
            guard distance > 0 else { return }
            let point = ray.origin + ray.direction * distance
            guard point.x.isFinite, point.z.isFinite, point.x >= 0, point.x < 256, point.z >= 0, point.z < 256 else { return }
            model.cancel(); model.selected = .init(x: Int(point.x), z: Int(point.z))
        }
        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            let point = gesture.translation(in: view)
            if gesture.state == .began { previousPan = point }
            let dx = Float(point.x - previousPan.x), dy = Float(point.y - previousPan.y)
            previousPan = point
            if gesture.numberOfTouches >= 2 && !model.playing {
                let scale = model.distance / 400
                model.focus.x = Float(WorldNavigation.clamp(Double(model.focus.x - (dx * cos(model.yaw) + dy * sin(model.yaw)) * scale)))
                model.focus.z = Float(WorldNavigation.clamp(Double(model.focus.z - (-dx * sin(model.yaw) + dy * cos(model.yaw)) * scale)))
            } else { model.yaw -= dx * 0.007 }
        }
        @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.scale.isFinite, gesture.scale > 0 else { return }
            model.distance = min(40, max(5, model.distance / Float(gesture.scale)))
            gesture.scale = 1
        }
    }
}

/// Each cell owns its player/timeline even when several cells reference one asset.
@MainActor
final class CellPlayback {
    let reference: MediaReference
    let root: URL
    weak var face: ModelEntity?
    let live: Bool
    let start: Double
    var source: CGImageSource?
    var delays: [Double] = []
    var currentFrame = -1
    var player: AVPlayer?
    var loopToken: NSObjectProtocol?
    var onError: ((String) -> Void)?
    init(reference: MediaReference, root: URL, face: ModelEntity, live: Bool, start: Double) {
        self.reference = reference; self.root = root; self.face = face; self.live = live; self.start = start
    }
    func stop() {
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
        if let loopToken { NotificationCenter.default.removeObserver(loopToken) }
        loopToken = nil
    }
    func load() {
        do {
            switch reference.kind {
            case .text, .number, .icon:
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
                let image = renderer.image { context in
                    UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
                    if reference.kind == .icon, let icon = UIImage(systemName: reference.assetID) {
                        icon.withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 96, y: 96, width: 320, height: 320))
                    } else {
                        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                        (reference.assetID as NSString).draw(in: CGRect(x: 20, y: 160, width: 472, height: 330), withAttributes: [
                            .font: UIFont.systemFont(ofSize: 52, weight: .bold), .foregroundColor: UIColor.black, .paragraphStyle: paragraph])
                    }
                }
                if let cg = image.cgImage { try texture(cg) }
            case .image, .gif, .video:
                // Serialized references are names, never arbitrary paths or remote URLs.
                guard reference.assetID == (reference.assetID as NSString).lastPathComponent,
                      ![".", ".."].contains(reference.assetID) else { throw SandboxError.message("媒体路径无效") }
                let url = root.appendingPathComponent("Media").appendingPathComponent(reference.assetID)
                guard FileManager.default.fileExists(atPath: url.path) else { throw SandboxError.message("媒体文件缺失") }
                if reference.kind == .video {
                    guard live else { label("视频 · 暂停"); return }
                    let player = AVPlayer(url: url); player.isMuted = true
                    self.player = player
                    face?.model?.materials = [VideoMaterial(avPlayer: player)]
                    loopToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem, queue: .main) { [weak player] _ in player?.seek(to: .zero); player?.play() }
                    player.play()
                } else {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw SandboxError.message("无法解码图片") }
                    self.source = source
                    let count = CGImageSourceGetCount(source)
                    guard count > 0, count <= 300 else { throw SandboxError.message("GIF 原型最多支持 300 帧") }
                    if reference.kind == .gif && live {
                        delays = (0..<count).map { index in
                            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                            let seconds = (gif?[kCGImagePropertyGIFUnclampedDelayTime] ?? gif?[kCGImagePropertyGIFDelayTime]) as? Double
                            return GIFTiming.normalizedDelay(seconds)
                        }
                    }
                    try frame(0)
                }
            case .model3D: label("3D")
            }
        } catch { label("媒体不可用"); onError?("媒体加载失败：\(error.localizedDescription)") }
    }
    func label(_ text: String) {
        let mesh = MeshResource.generateText(text, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.1))
        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .black, isMetallic: false)])
        entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        entity.position = [-0.4, 0.01, 0]
        face?.addChild(entity)
    }
    func texture(_ image: CGImage) throws {
        let texture = try TextureResource.generate(from: image, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))
        face?.model?.materials = [material]
    }
    func frame(_ index: Int) throws {
        guard let source else { return }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 512, kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
            throw SandboxError.message("无法解码媒体帧")
        }
        try texture(image); currentFrame = index
    }
    func update(elapsed: Double) {
        guard !delays.isEmpty else { return }
        let index = GIFTiming.frameIndex(elapsed: elapsed - start, delays: delays, loop: true)
        if index != currentFrame {
            do { try frame(index) }
            catch { delays = []; onError?("GIF 解码失败") }
        }
    }
}
