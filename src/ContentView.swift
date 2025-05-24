import SwiftUI

struct ContentView: View {
    @State var isAuthenticated = false

    var body: some View {
    Group {
      if isAuthenticated {
        ListsView()
      } else {
        AuthView()
      }
    }
    .task {
      for await state in supabase.auth.authStateChanges {
        if [.initialSession, .signedIn, .signedOut].contains(state.event) {
          isAuthenticated = state.session != nil
        }
      }
    }
  }
}
