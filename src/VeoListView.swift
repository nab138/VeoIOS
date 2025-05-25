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
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var isExiting: Bool = false
    @State private var exitingScale: CGFloat = 1.0
    
    var nonRenamableIndices: Set<Int> = [] // Indices of non-renamable items, default empty
    // Helper to determine if an item is editable
    func isEditable(idx: Int) -> Bool {
        onRename != nil && idx < items.count && !nonRenamableIndices.contains(idx)
    }
    
    // Helper to get safe area insets in a modern way
    private var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets ?? .zero
    }

    var body: some View {
        ZStack {
            // Main scalable content with proper backgrounds
            ScrollView {
                VStack(spacing: 0) {
                    // Title area with color1
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, safeAreaInsets.top + 24)
                        .padding(.bottom, 24)
                        .background(VeoListView.color1)
                    
                    // List items
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
                    
                    // Bottom spacer to fill remaining space
                    Spacer(minLength: safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity)
                        .background(VeoListView.color2)
                }
                .background(VeoListView.color2)
            }
            .background(
                ZStack {
                    // Background fills for overscroll (non-scaling)
                    VeoListView.color2.ignoresSafeArea()
                    VStack {
                        VeoListView.color1.ignoresSafeArea(edges: .top)
                            .frame(height: 200) // Tall enough for overscroll
                        Spacer()
                    }
                }
            )
            .highPriorityGesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, state, transaction in
                        if isTopLevel { return }
                        state = value
                    }
                    .onEnded { value in
                        if isTopLevel { return }
                        if value < 0.7 {
                            isExiting = true
                            exitingScale = value
                            onPinchExit?()
                        }
                    }
            )
            .scaleEffect(isExiting ? exitingScale : pinchScale)
            .animation(isExiting ? nil : .easeOut(duration: 0.18), value: pinchScale)
        }
        .ignoresSafeArea()
    }
    
    func steppedGradientColor(for index: Int) -> Color {
        guard items.count > 0 else { return VeoListView.color2 }
        return Color.steppedGradientColor(for: index, count: items.count)
    }
}

// Helper to get keyWindow for safeAreaInsets
extension UIWindowScene {
    var keyWindow: UIWindow? {
        self.windows.first { $0.isKeyWindow }
    }
}