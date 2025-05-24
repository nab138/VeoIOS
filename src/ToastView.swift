import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
            .transition(.opacity)
            .zIndex(1)
            .padding(.bottom, 40)
    }
}

struct ToastModifier: ViewModifier {
    let message: String?
    var isPresented: SwiftUI.Binding<Bool>
    var autoDismissAfter: Double?

    func body(content: Content) -> some View {
        ZStack {
            content
            if let message = message, isPresented.wrappedValue {
                ToastView(message: message)
                    .onAppear {
                        if let duration = autoDismissAfter {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                if isPresented.wrappedValue {
                                    isPresented.wrappedValue = false
                                }
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: isPresented.wrappedValue)
    }
}

extension View {
    func toast(
        message: String?,
        isPresented: SwiftUI.Binding<Bool>,
        autoDismissAfter: Double? = 2
    ) -> some View {
        self.modifier(ToastModifier(message: message, isPresented: isPresented, autoDismissAfter: autoDismissAfter))
    }
}