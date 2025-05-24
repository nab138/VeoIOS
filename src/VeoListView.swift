import SwiftUI

struct VeoListView: View {
    let title: String
    let items: [String]
    var onRename: ((Int, String) -> Void)? = nil
    var onItemTap: ((Int) -> Void)? = nil
    var onPinchExit: (() -> Void)? = nil
    var isTopLevel: Bool = false
    static let color1 = Color(hex: "#0072ce")
    static let color2 = Color(hex: "#00b6a0")
    @State private var editingIndex: Int? = nil
    @State private var editingText: String = ""
    @State private var pinchScale: CGFloat = 1.0
    @State private var isExiting: Bool = false
    
    var nonRenamableIndices: Set<Int> = [] // Indices of non-renamable items, default empty
    // Helper to determine if an item is editable
    func isEditable(idx: Int) -> Bool {
        onRename != nil && idx < items.count && !nonRenamableIndices.contains(idx)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 24)
                .background(VeoListView.color1)
            ForEach(items.indices, id: \.self) { idx in
                ZStack(alignment: .leading) {
                    if editingIndex == idx, isEditable(idx: idx) {
                        TextField("Rename", text: $editingText, onCommit: {
                            onRename?(idx, editingText)
                            editingIndex = nil
                        })
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .background(steppedGradientColor(for: idx))
                        .onAppear { editingText = items[idx] }
                    } else {
                        HStack(spacing: 0) {
                            Text(items[idx])
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.clear)
                                .onTapGesture {
                                    if isEditable(idx: idx) {
                                        editingIndex = idx
                                        editingText = items[idx]
                                    } else if let onItemTap = onItemTap {
                                        onItemTap(idx)
                                    }
                                }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal)
                        .background(steppedGradientColor(for: idx))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Only trigger onItemTap if not editing
                            if let onItemTap = onItemTap, editingIndex != idx {
                                onItemTap(idx)
                            }
                        }
                    }
                }
            }
            Spacer()
                .frame(maxWidth: .infinity)
                .background(steppedGradientColor(for: items.count))
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    if isTopLevel {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.18)) {
                        pinchScale = value
                    }
                }
                .onEnded { value in
                    if isTopLevel {
                        return
                    }
                    if value < 0.7 {
                        isExiting = true
                        onPinchExit?()
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            pinchScale = 1.0
                        }
                    }
                }
        )
        .scaleEffect(pinchScale)
        .animation(isExiting ? nil : .easeOut(duration: 0.18), value: pinchScale)
        .onChange(of: isExiting) { exiting in
            if !exiting {
                pinchScale = 1.0
            }
        }
    }
    
    func steppedGradientColor(for index: Int) -> Color {
        guard items.count > 0 else { return VeoListView.color2 }
        return VeoListView.steppedGradientColor(for: index, count: items.count)
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
}