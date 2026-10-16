import SwiftUI
import UIKit
import ARKit
import SceneKit

/// Показывает камеру ARKit и рисует накопленное облако точек.
struct ARViewContainer: UIViewRepresentable {
    let session: ARSession
    let store: PointCloudStore
    let showAccumulated: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, showAccumulated: showAccumulated)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = false
        view.autoenablesDefaultLighting = false
        view.scene = SCNScene()
        view.debugOptions = [.showFeaturePoints]   // «сырые» точки ARKit текущего кадра
        view.scene?.rootNode.addChildNode(context.coordinator.cloudNode)
        context.coordinator.view = view
        context.coordinator.startTimer()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.showAccumulated = showAccumulated
    }

    final class Coordinator {
        let cloudNode = SCNNode()
        let store: PointCloudStore
        weak var view: ARSCNView?
        var showAccumulated: Bool

        private var timer: Timer?
        private let maxViz = 120_000

        init(store: PointCloudStore, showAccumulated: Bool) {
            self.store = store
            self.showAccumulated = showAccumulated
        }

        func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.rebuild()
            }
        }

        deinit {
            timer?.invalidate()
        }

        func rebuild() {
            guard showAccumulated else {
                cloudNode.geometry = nil
                return
            }
            var pts = store.points
            guard !pts.isEmpty else {
                cloudNode.geometry = nil
                return
            }
            if pts.count > maxViz {
                let step = max(1, pts.count / maxViz)
                var reduced = [SIMD3<Float>]()
                reduced.reserveCapacity(maxViz)
                var i = 0
                while i < pts.count {
                    reduced.append(pts[i])
                    i += step
                }
                pts = reduced
            }

            let verts = pts.map { SCNVector3($0.x, $0.y, $0.z) }
            let source = SCNGeometrySource(vertices: verts)
            let indices = (0..<verts.count).map { UInt32($0) }
            let element = SCNGeometryElement(indices: indices, primitiveType: .point)
            element.pointSize = 4
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = 8

            let geometry = SCNGeometry(sources: [source], elements: [element])
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.systemYellow
            material.isDoubleSided = true
            geometry.materials = [material]

            cloudNode.geometry = geometry
        }
    }
}
