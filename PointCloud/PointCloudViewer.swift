import SwiftUI
import UIKit
import SceneKit
import Foundation

// MARK: - Экран просмотра

/// Полноэкранный просмотрщик облака точек: вращение пальцем, масштаб щипком.
/// Работает без запуска камеры — показывает то, что уже накоплено.
struct PointCloudViewerScreen: View {
    let points: [SIMD3<Float>]
    let voxelSize: Float

    @Environment(\.dismiss) private var dismiss
    @State private var resetID = UUID()
    @State private var sizeText: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PointCloudViewerView(points: points, voxelSize: voxelSize)
                .id(resetID)
                .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 6) {
                Text("Точек: \(points.count)")
                if let sizeText = sizeText {
                    Text("Габариты: \(sizeText)")
                }
                Text("Перетаскивание — вращение, щипок — масштаб")
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("Сброс вида") {
                        resetID = UUID()
                    }
                    Button("Закрыть") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .onAppear {
            if sizeText == nil {
                sizeText = Self.dimensionsText(of: points)
            }
        }
    }

    /// Габариты облака в сантиметрах (ARKit хранит координаты в метрах).
    static func dimensionsText(of points: [SIMD3<Float>]) -> String? {
        guard let first = points.first else { return nil }
        var mn = first
        var mx = first
        for p in points {
            if p.x < mn.x { mn.x = p.x }
            if p.x > mx.x { mx.x = p.x }
            if p.y < mn.y { mn.y = p.y }
            if p.y > mx.y { mx.y = p.y }
            if p.z < mn.z { mn.z = p.z }
            if p.z > mx.z { mx.z = p.z }
        }
        let w = Double((mx.x - mn.x) * 100)
        let h = Double((mx.y - mn.y) * 100)
        let d = Double((mx.z - mn.z) * 100)
        return String(format: "%.1f × %.1f × %.1f см", w, h, d)
    }
}

// MARK: - SceneKit-контрол

struct PointCloudViewerView: UIViewRepresentable {
    let points: [SIMD3<Float>]
    let voxelSize: Float

    func makeCoordinator() -> Coordinator {
        Coordinator(points: points)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)

        let scene = SCNScene()
        scene.background.contents = UIColor(white: 0.06, alpha: 1)
        scene.rootNode.addChildNode(context.coordinator.cloudNode)
        scene.rootNode.addChildNode(context.coordinator.cameraNode)
        view.scene = scene
        view.pointOfView = context.coordinator.cameraNode
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    final class Coordinator {
        let cloudNode = SCNNode()
        let cameraNode = SCNNode()

        private let points: [SIMD3<Float>]
        private var radius: Float = 1

        init(points: [SIMD3<Float>]) {
            self.points = points
            buildCloud()
            buildCamera()
        }

        private func buildCloud() {
            guard let first = points.first else { return }

            var mn = first
            var mx = first
            for p in points {
                if p.x < mn.x { mn.x = p.x }
                if p.x > mx.x { mx.x = p.x }
                if p.y < mn.y { mn.y = p.y }
                if p.y > mx.y { mx.y = p.y }
                if p.z < mn.z { mn.z = p.z }
                if p.z > mx.z { mx.z = p.z }
            }

            // Облако центрируется в начале координат: вращение идёт вокруг него.
            let cx = (mn.x + mx.x) * 0.5
            let cy = (mn.y + mx.y) * 0.5
            let cz = (mn.z + mx.z) * 0.5
            let ex = (mx.x - mn.x) * 0.5
            let ey = (mx.y - mn.y) * 0.5
            let ez = (mx.z - mn.z) * 0.5
            radius = Swift.max(ex, Swift.max(ey, ez))

            var verts = [SCNVector3]()
            verts.reserveCapacity(points.count)
            for p in points {
                verts.append(SCNVector3(p.x - cx, p.y - cy, p.z - cz))
            }

            let source = SCNGeometrySource(vertices: verts)
            let indices = (0..<verts.count).map { UInt32($0) }
            let element = SCNGeometryElement(indices: indices, primitiveType: .point)
            element.pointSize = 3
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = 6

            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.systemYellow
            material.isDoubleSided = true
            geometry.materials = [material]

            cloudNode.geometry = geometry
        }

        private func buildCamera() {
            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.zFar = 10_000
            cameraNode.camera = camera

            let dist = Swift.max(radius * 3.0, 0.3)
            cameraNode.position = SCNVector3(0, dist * 0.25, dist)
            cameraNode.look(at: SCNVector3(0, 0, 0))
        }
    }
}
