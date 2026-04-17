import Foundation

extension Double {
    var bacFormatted: String {
        String(format: "%.3f%%", self)
    }

    var bacShort: String {
        String(format: "%.2f%%", self)
    }
}
