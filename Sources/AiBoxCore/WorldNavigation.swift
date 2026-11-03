import Foundation

/// Grid units, adapted from Moonlight camera bounds. RealityKit projection stays in the app.
public enum WorldNavigation {
    public static func clamp(_ value: Double, lower: Double = 0, upper: Double = 256) -> Double {
        guard value.isFinite else { return lower }
        return min(upper, max(lower, value))
    }

    /// Swept, axis-separated circle/AABB movement. Every object is a solid unit cube
    /// scaled at its transform; elevated cubes above player height are passable.
    public static func move(x: Double, z: Double, dx: Double, dz: Double,
                            world: AiBoxWorld, radius: Double = 0.25) -> (x: Double, z: Double) {
        guard [x, z, dx, dz, radius].allSatisfy(\.isFinite),
              (0.1...0.5).contains(radius), abs(dx) <= 4, abs(dz) <= 4 else { return (x, z) }
        var px = x, pz = z
        let steps = max(1, Int(ceil(max(abs(dx), abs(dz)) / 0.1)))
        func allowed(_ x: Double, _ z: Double) -> Bool {
            guard x >= radius, z >= radius, x <= 256 - radius, z <= 256 - radius else { return false }
            return !world.objects.contains { object in
                let t = object.transform
                guard t.y < 1.8, t.y + t.scale > 0 else { return false }
                // Conservative bounds for rotated cubes.
                let half = t.scale * (abs(cos(t.yawRadians)) + abs(sin(t.yawRadians))) / 2
                let nx = min(t.x + half, max(t.x - half, x))
                let nz = min(t.z + half, max(t.z - half, z))
                return (x - nx) * (x - nx) + (z - nz) * (z - nz) < radius * radius
            }
        }
        for _ in 0..<steps {
            let nextX = px + dx / Double(steps)
            if allowed(nextX, pz) { px = nextX }
            let nextZ = pz + dz / Double(steps)
            if allowed(px, nextZ) { pz = nextZ }
        }
        return (px, pz)
    }
}
