import SwiftUI

struct VeoListView: View {
    let title: String
    let items: [String]
    var onRename: ((Int, String) -> Void)? = nil
    var onAdd: ((String) -> Void)? = nil
    var onItemTap: ((Int) -> Void)? = nil
    var onPinchExit: (() -> Void)? = nil
    var onDelete: ((Int) -> Void)? = nil
    var isTopLevel: Bool = false
    static let color1 = Color(hex: "#0072ce")
    static let color2 = Color(hex: "#00b6a0")
    @State private var editingIndex: Int? = nil
    @State private var editingText: String = ""
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var isExiting: Bool = false
    @State private var exitingScale: CGFloat = 1.0
    @State private var scrollPosition: CGPoint = .zero
    @State private var newItemText: String = ""
    @State private var newItemBoxLocked: Bool = false
    @FocusState private var isFocused: Bool
    @State private var isDeletingNewItemBox: Bool = false
    @GestureState private var swipePosition: CGSize = .zero
    @State private var swipeIndex: Int? = nil
    @State private var lastSwipeWidth: CGFloat = 0


    var nonRenamableIndices: Set<Int> = []
    func isEditable(idx: Int) -> Bool {
        onRename != nil && idx < items.count && !nonRenamableIndices.contains(idx)
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets ?? .zero
    }

    let rowHeight: CGFloat = 64
    let deleteOffset: CGFloat = -48

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if overscrollHeight == 0 && !newItemBoxLocked {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, safeAreaInsets.top + 24)
                            .padding(.bottom, 24)
                            .background(VeoListView.color1)
                    } else {
                        Spacer(minLength: titleBarHeight - (newItemBoxLocked ? 0 : max(0, scrollPosition.y)))
                    }

                    // New item box: appears when overscrolling or locked open
                    if (overscrollHeight > 0 || newItemBoxLocked) && !isDeletingNewItemBox {
                        ZStack(alignment: .leading) {
                            TextField("Add new item" + (newItemBoxLocked ? "!" : "?"), text: $newItemText, onCommit: {
                                if(newItemText.isEmpty) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isDeletingNewItemBox = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        newItemText = ""
                                        newItemBoxLocked = false
                                        scrollPosition = .zero
                                        isDeletingNewItemBox = false
                                    }
                                } else {
                                    if let onAdd = onAdd {
                                        onAdd(newItemText)
                                    }
                                }
                                newItemText = ""
                                newItemBoxLocked = false
                                scrollPosition = .zero
                            })
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, maxHeight: rowHeight, alignment: .leading)
                            .background(steppedGradientColor(for: 0))
                            .focused($isFocused)
                            
                        }
                        .frame(height: overscrollHeight)
                        .transition(.move(edge: .top))
                        .animation(.easeInOut(duration: 0.3), value: isDeletingNewItemBox)
                    }

                    // List items
                    ForEach(items.indices, id: \.self) { idx in
                        ZStack(alignment: .leading) {
                            // Delete button behind the row, aligned to the right
                            if isEditable(idx: idx) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "trash")
                                        .frame(width: UIScreen.main.bounds.size.width * 0.5, height: 64, alignment: .trailing)
                                        .padding(.horizontal)
                                        .opacity(swipeDist < deleteOffset ? 1.0 : 0.5)
                                        .animation(.easeInOut(duration: 0.15), value: swipeDist)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.red)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                            }
                            // Row content
                            if editingIndex == idx, isEditable(idx: idx) {
                                TextField("Rename", text: $editingText, onCommit: {
                                    onRename?(idx, editingText)
                                    editingIndex = nil
                                })
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                                .background(steppedGradientColor(for: Double(idx) + (overscrollHeight / rowHeight)))
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
                                .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
                                .padding(.horizontal)
                                .background(steppedGradientColor(for: Double(idx) + (overscrollHeight / rowHeight)))
                                .contentShape(Rectangle())
                                .offset(x: swipeIndex == idx ? swipeDist : 0, y: 0)
                                .animation(.easeInOut(duration: 0.15), value: swipePosition)
                                .onTapGesture {
                                    if let onItemTap = onItemTap, editingIndex != idx {
                                        onItemTap(idx)
                                    }
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .updating($swipePosition) { value, state, transaction in
                                            if isEditable(idx: idx) {
                                                state = value.translation
                                            }
                                        }
                                        .onChanged { value in
                                            if isEditable(idx: idx) {
                                                swipeIndex = idx
                                                // play haptics if it just got past deleteOffset
                                                if value.translation.width < deleteOffset && lastSwipeWidth >= deleteOffset {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                }
                                                lastSwipeWidth = value.translation.width // <-- Track last swipe width
                                            }
                                        }
                                        .onEnded { value in
                                            if isEditable(idx: idx) {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    swipeIndex = nil
                                                }
                                                if value.translation.width < deleteOffset {
                                                    onDelete?(idx)
                                                }
                                                lastSwipeWidth = 0
                                            }
                                        }
                                )
                            }
                        }
                    }
                    
                    Spacer(minLength: safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity)
                        .background(VeoListView.color2)
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                })
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    if !newItemBoxLocked {
                        if value.y > 0 {
                            self.scrollPosition = CGPoint(x: value.x, y: min(rowHeight, value.y))
                            newItemText = ""
                        } else {
                            self.scrollPosition = value
                        }
                        if value.y >= rowHeight {
                            DispatchQueue.main.async {
                                newItemBoxLocked = true
                                isFocused = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .background(
                ZStack {
                    VeoListView.color2.ignoresSafeArea()
                    VStack {
                        VeoListView.color1.ignoresSafeArea(edges: .top)
                            .frame(height: 170)
                        Spacer()
                    }
                }
            )
            .simultaneousGesture(
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
            .scrollDisabled(newItemBoxLocked)

            // Pinned header: only when overscrolling or locked open
            if overscrollHeight > 0 || newItemBoxLocked {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, safeAreaInsets.top + 24)
                        .padding(.bottom, 24)
                        .background(VeoListView.color1)
                        .frame(height: titleBarHeight)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.move(edge: .top))
            }
        }
        .ignoresSafeArea()
        .onChange(of: overscrollHeight) { newValue in
            // Focus the new item field when it appears
            if (newValue > 0 || newItemBoxLocked) {
                DispatchQueue.main.async {
                }
            }
        }
    }

    var titleBarHeight: CGFloat {
        safeAreaInsets.top + 24 + 24 + UIFont.preferredFont(forTextStyle: .largeTitle).lineHeight
    }

    // Clamp overscroll to rowHeight, or keep open if locked
    var overscrollHeight: CGFloat {
        if newItemBoxLocked { return rowHeight }
        return max(0, min(rowHeight, scrollPosition.y))
    }


    var swipeDist: CGFloat {
        if(swipePosition.width < deleteOffset) {
            return max(deleteOffset + (swipePosition.width - deleteOffset) * 0.4, -UIScreen.main.bounds.size.width * 0.5)
        }
        return swipePosition.width
    }

    func steppedGradientColor(for index: Double) -> Color {
        // New item box uses the same gradient as the first item
        let count = max(items.count, 1)
        let idx = max(0, index)
        return Color.steppedGradientColor(for: idx, count: Double(count) + (overscrollHeight / rowHeight))
    }
}


extension UIWindowScene {
    var keyWindow: UIWindow? {
        self.windows.first { $0.isKeyWindow }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    }
}