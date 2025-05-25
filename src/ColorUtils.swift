import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255.0
        g = Double((int >> 8) & 0xFF) / 255.0
        b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    
    var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        typealias NativeColor = UIColor
        #elseif canImport(AppKit)
        typealias NativeColor = NSColor
        #endif
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        NativeColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }

    static func steppedGradientColor(for index: Int, count: Int) -> Color {
        guard count > 0 else { return VeoListView.color2 }
        let t = Double(index) / Double(count)
        return Color(
            red: VeoListView.color1.components.red + (VeoListView.color2.components.red - VeoListView.color1.components.red) * t,
            green: VeoListView.color1.components.green + (VeoListView.color2.components.green - VeoListView.color1.components.green) * t,
            blue: VeoListView.color1.components.blue + (VeoListView.color2.components.blue - VeoListView.color1.components.blue) * t
        )
    }
}