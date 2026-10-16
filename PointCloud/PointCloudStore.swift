import Foundation
import simd

/// Накопитель облака точек с дедупликацией по воксельной сетке.
///
/// ARKit отдаёт характерные точки (`ARFrame.rawFeaturePoints`) в мировых
/// координатах (метры). Между кадрами одни и те же точки повторяются, поэтому
/// мы складываем их в воксели (по умолчанию 1 см) и усредняем координаты.
final class PointCloudStore {
    private struct Voxel {
        var sum: SIMD3<Double>
        var n: Int
    }

    private var voxels: [SIMD3<Int32>: Voxel] = [:]
    private let lock = NSLock()

    /// Размер вокселя в метрах (например 0.01 = 1 см).
    var voxelSize: Float = 0.01

    /// Верхняя граница числа точек (защита от переполнения памяти).
    var maxPoints: Int = 600_000

    private(set) var count: Int = 0

    func reset() {
        lock.lock(); defer { lock.unlock() }
        voxels.removeAll(keepingCapacity: true)
        count = 0
    }

    func add(_ points: [SIMD3<Float>]) {
        guard voxelSize > 0 else { return }
        lock.lock(); defer { lock.unlock() }
        for p in points {
            let key = SIMD3<Int32>(
                Int32((p.x / voxelSize).rounded()),
                Int32((p.y / voxelSize).rounded()),
                Int32((p.z / voxelSize).rounded())
            )
            if var v = voxels[key] {
                v.sum += SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z))
                v.n += 1
                voxels[key] = v
            } else if voxels.count < maxPoints {
                voxels[key] = Voxel(sum: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)), n: 1)
            }
        }
        count = voxels.count
    }

    var points: [SIMD3<Float>] {
        lock.lock(); defer { lock.unlock() }
        var out = [SIMD3<Float>]()
        out.reserveCapacity(voxels.count)
        for v in voxels.values {
            let s = v.sum / Double(v.n)
            out.append(SIMD3<Float>(Float(s.x), Float(s.y), Float(s.z)))
        }
        return out
    }
}
