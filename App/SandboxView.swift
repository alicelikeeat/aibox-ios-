import SwiftUI
import UniformTypeIdentifiers

struct SandboxView: View {
    @StateObject private var model = SandboxModel()
    @State private var importing = false
    @State private var photoImporting = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AiBox").font(.headline)
                Spacer()
                Button(model.playing ? "编辑" : "游玩") {
                    model.cancel(); model.joystick = .zero; model.playing.toggle()
                }.disabled(model.busy || model.loadFailed)
                Button("保存") { Task { await model.save() } }
                    .disabled(model.busy || model.loadFailed || model.pending != nil)
            }.padding()
            ZStack(alignment: .bottomLeading) {
                SandboxScene(model: model)
                if model.playing {
                    joystick.padding(24)
                } else {
                    Text("单指旋转 · 双指平移 · 捏合缩放")
                        .font(.caption).padding(8).background(.ultraThinMaterial).padding(8)
                }
            }
            HStack {
                if model.busy { ProgressView() }
                Text(model.status).font(.caption)
            }.padding(8).frame(maxWidth: .infinity)
            if !model.playing {
                VStack {
                    HStack {
                        Text("格子 \(model.selected.x), \(model.selected.z)")
                        Text("对象 \(model.editor.world.objects.count)").accessibilityIdentifier("worldCount")
                        Spacer()
                        Button("撤销", action: model.undo)
                        Button("重做", action: model.redo)
                    }
                    Picker("工具", selection: $model.tool) {
                        ForEach(SandboxModel.tools, id: \.self) { Text($0) }
                    }.pickerStyle(.menu)
                    if ["文字", "数字", "图标"].contains(model.tool) {
                        TextField(model.tool == "图标" ? "SF Symbol，例如 star.fill" : "显示内容", text: $model.value)
                            .textFieldStyle(.roundedBorder)
                    }
                    if ["图片", "GIF", "视频"].contains(model.tool) {
                        HStack {
                            Button("从相册导入") { photoImporting = true }
                            Button("从文件导入") { importing = true }
                        }
                        Text(model.importedAsset == nil ? "视频最多 256 MiB；图片/GIF 最多 32 MiB" : "已导入媒体，请预览后确认")
                            .font(.caption)
                    }
                    HStack {
                        if model.pending != nil {
                            Button("取消预览", action: model.cancel)
                            Button("确认编辑", action: model.confirm).buttonStyle(.borderedProminent)
                        } else {
                            Button("预览编辑", action: model.draft).buttonStyle(.borderedProminent)
                        }
                    }
                }.padding().disabled(!model.canEdit)
            }
        }
        .task { await model.load() }
        .onChange(of: model.tool) { _ in model.cancel(); model.importedAsset = nil }
        .onChange(of: model.value) { _ in model.cancel() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.playing = false; model.joystick = .zero }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes) { result in
            switch result {
            case .success(let url): Task { await model.importFile(url) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { model.error = error.localizedDescription }
            }
        }
        .sheet(isPresented: $photoImporting) {
            MediaPhotoPicker(kind: model.importKind, onPick: model.importPhoto,
                             onDismiss: { photoImporting = false })
        }
        .alert("AiBox", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var importTypes: [UTType] {
        model.tool == "视频" ? [.movie, .video] : model.tool == "GIF" ? [.gif] : [.image]
    }
    private var joystick: some View {
        Circle().fill(.ultraThinMaterial).frame(width: 110, height: 110)
            .overlay(Circle().fill(.blue).frame(width: 42, height: 42)
                .offset(x: CGFloat(model.joystick.x) * 35, y: CGFloat(model.joystick.y) * 35))
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                var input = SIMD2(Float(value.location.x - 55), Float(value.location.y - 55)) / 35
                let length = sqrt(input.x * input.x + input.y * input.y)
                if length > 1 { input /= length }
                model.joystick = input
            }.onEnded { _ in model.joystick = .zero })
            .accessibilityLabel("角色移动摇杆")
    }
}
