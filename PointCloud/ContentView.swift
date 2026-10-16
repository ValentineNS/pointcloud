import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var controller = ARSessionController()

    @State private var showShare = false
    @State private var exportURL: URL?
    @State private var message: String?

    @State private var voxelMM: Double = 10
    @State private var showAccumulated = true

    var body: some View {
        ZStack {
            ARViewContainer(session: controller.arSession,
                            store: controller.store,
                            showAccumulated: showAccumulated)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                controls
            }
            .padding()
        }
        .sheet(isPresented: $showShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Экспорт", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
        .onChange(of: voxelMM) { value in
            controller.store.voxelSize = Float(value / 1000.0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Облако точек (ARKit)")
                .font(.headline)
            Text("Точек: \(controller.pointCount)")
                .font(.system(.title2, design: .monospaced))
            Text("Трекинг: \(controller.trackingState) · \(controller.status)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Воксель")
                Slider(value: $voxelMM, in: 5...50, step: 5)
                Text("\(Int(voxelMM)) мм")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 60, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Button(buttonTitle) {
                    controller.toggle()
                }
                .buttonStyle(.borderedProminent)

                Button("Сброс") {
                    controller.reset()
                }
                .buttonStyle(.bordered)

                Button("Экспорт PLY") {
                    export()
                }
                .buttonStyle(.bordered)
                .disabled(controller.pointCount == 0)
            }

            Toggle("Показывать накопленное облако", isOn: $showAccumulated)
                .font(.footnote)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var buttonTitle: String {
        if !controller.hasStarted { return "Старт" }
        return controller.isScanning ? "Пауза" : "Продолжить"
    }

    private func export() {
        let pts = controller.store.points
        guard !pts.isEmpty else { return }

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let name = "cloud_\(df.string(from: Date())).ply"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        do {
            try PLYWriter.write(pts, to: url, binary: true)
            exportURL = url
            showShare = true
        } catch {
            message = "Ошибка экспорта: \(error.localizedDescription)"
        }
    }
}
