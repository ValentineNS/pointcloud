import Foundation
import ARKit

/// Управляет ARKit-сессией и накапливает характерные точки в облако.
final class ARSessionController: NSObject, ObservableObject, ARSessionDelegate {
    @Published var pointCount: Int = 0
    @Published var isScanning: Bool = false
    @Published var hasStarted: Bool = false
    @Published var status: String = "Нажмите «Старт»"
    @Published var trackingState: String = "—"

    let store = PointCloudStore()
    let arSession = ARSession()

    override init() {
        super.init()
        arSession.delegate = self
    }

    /// Одна кнопка: старт → пауза → продолжение.
    func toggle() {
        if !hasStarted {
            start()
        } else if isScanning {
            pause()
        } else {
            resume()
        }
    }

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "ARKit не поддерживается на этом устройстве"
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        store.reset()
        pointCount = 0
        hasStarted = true
        isScanning = true
        status = "Сканирование…"
    }

    func pause() {
        isScanning = false
        status = "Пауза"
    }

    func resume() {
        isScanning = true
        status = "Сканирование…"
    }

    func reset() {
        store.reset()
        pointCount = 0
        status = "Сброшено"
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateTracking(frame.camera.trackingState)

        guard isScanning else { return }
        guard case .normal = frame.camera.trackingState else { return }

        if let cloud = frame.rawFeaturePoints, !cloud.points.isEmpty {
            store.add(cloud.points)
            let c = store.count
            DispatchQueue.main.async { self.pointCount = c }
        }
    }

    private func updateTracking(_ state: ARCamera.TrackingState) {
        let text: String
        switch state {
        case .normal:
            text = "норма"
        case .notAvailable:
            text = "нет"
        case .limited(let reason):
            switch reason {
            case .initializing:          text = "инициализация"
            case .excessiveMotion:       text = "быстрое движение"
            case .insufficientFeatures:  text = "мало деталей"
            case .relocalizing:          text = "перелокализация"
            @unknown default:            text = "ограничено"
            }
        }
        if trackingState != text {
            DispatchQueue.main.async { self.trackingState = text }
        }
    }
}
