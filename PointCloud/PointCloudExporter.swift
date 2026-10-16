import Foundation
import simd

/// Форматы экспорта облака точек.
enum PointCloudFormat: String, CaseIterable, Identifiable {
    case ply = "PLY"
    case xyz = "XYZ"
    case csv = "CSV"

    var id: String { rawValue }

    /// Короткое имя для кнопки/переключателя.
    var title: String { rawValue }

    var fileExtension: String {
        switch self {
        case .ply: return "ply"
        case .xyz: return "xyz"
        case .csv: return "csv"
        }
    }

    /// Подсказка под переключателем.
    var hint: String {
        switch self {
        case .ply:
            return "PLY — двоичный, для CloudCompare / MeshLab"
        case .xyz:
            return "XYZ — текст «X Y Z» (метры), читается в CATIA (Import → Free ASCII)"
        case .csv:
            return "CSV — текст через запятую, для Excel / скриптов"
        }
    }
}

/// Экспорт точек в текстовый формат (свободный ASCII).
enum TextPointWriter {
    /// Разделитель дробной части всегда «.», независимо от локали телефона.
    private static let posix = Locale(identifier: "en_US_POSIX")

    static func write(_ points: [SIMD3<Float>],
                      to url: URL,
                      separator: String,
                      decimals: Int = 6) throws {
        var text = ""
        text.reserveCapacity(points.count * 48)
        let fmt = "%.\(decimals)f\(separator)%.\(decimals)f\(separator)%.\(decimals)f\n"
        for p in points {
            text += String(format: fmt, locale: posix,
                           arguments: [Double(p.x), Double(p.y), Double(p.z)])
        }
        guard let data = text.data(using: .ascii) else {
            throw NSError(domain: "PointCloudExport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось закодировать текст"])
        }
        try data.write(to: url)
    }
}

/// Единая точка входа для экспорта облака точек.
enum PointCloudExporter {
    static func export(_ points: [SIMD3<Float>],
                       to url: URL,
                       format: PointCloudFormat) throws {
        switch format {
        case .ply:
            try PLYWriter.write(points, to: url, binary: true)
        case .xyz:
            try TextPointWriter.write(points, to: url, separator: " ")
        case .csv:
            try TextPointWriter.write(points, to: url, separator: ",")
        }
    }
}
