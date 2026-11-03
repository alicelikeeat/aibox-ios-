import Foundation

/// An editor transaction is prepared against a specific snapshot, previewed,
/// then committed as one reversible operation.
public struct WorldEdit: Sendable {
    public enum Operation: Sendable {
        case place(WorldObject)
        case remove(UUID)
        case move(UUID, GridPosition, WorldTransform)
    }

    public var operations: [Operation]

    public init(operations: [Operation]) {
        self.operations = operations
    }

    public func preview(in world: AiBoxWorld) throws -> AiBoxWorld {
        var candidate = world
        for operation in operations {
            switch operation {
            case .place(let object):
                guard object.isValid, !candidate.objects.contains(where: { $0.id == object.id }) else {
                    throw WorldEditError.invalidPlacement
                }
                candidate.objects.append(object)
            case .remove(let id):
                guard let index = candidate.objects.firstIndex(where: { $0.id == id }) else {
                    throw WorldEditError.objectNotFound
                }
                candidate.objects.remove(at: index)
            case .move(let id, let anchor, let transform):
                guard let index = candidate.objects.firstIndex(where: { $0.id == id }) else {
                    throw WorldEditError.objectNotFound
                }
                guard anchor.isValid, transform.isValid else { throw WorldEditError.invalidPlacement }
                candidate.objects[index].anchor = anchor
                candidate.objects[index].transform = transform
            }
        }
        try candidate.validate()
        return candidate
    }
}

public enum WorldEditError: Error, Equatable {
    case invalidPlacement
    case objectNotFound
    case stalePreview
}

public struct WorldEditor: Sendable {
    public private(set) var world: AiBoxWorld
    private var undoStack: [AiBoxWorld] = []
    private var redoStack: [AiBoxWorld] = []
    public let historyLimit: Int

    public init(world: AiBoxWorld = AiBoxWorld(), historyLimit: Int = 50) throws {
        try world.validate()
        self.world = world
        self.historyLimit = max(0, historyLimit)
    }

    public func preview(_ edit: WorldEdit) throws -> AiBoxWorld {
        try edit.preview(in: world)
    }

    /// Caller must present the preview and explicitly confirm before commit.
    /// Rechecks the preview to prevent applying an outdated edit.
    public mutating func commit(_ edit: WorldEdit, expectedPreview: AiBoxWorld) throws {
        let actual = try edit.preview(in: world)
        guard try AiBoxWorldCodec.encode(actual) == AiBoxWorldCodec.encode(expectedPreview) else {
            throw WorldEditError.stalePreview
        }
        if historyLimit > 0 {
            undoStack.append(world)
            if undoStack.count > historyLimit { undoStack.removeFirst() }
        }
        redoStack.removeAll()
        world = actual
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(world)
        world = previous
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        if historyLimit > 0 { undoStack.append(world) }
        world = next
        return true
    }
}
