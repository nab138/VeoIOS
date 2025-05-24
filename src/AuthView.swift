import SwiftUI

struct AuthView: View {
  @State var email = ""
  @State var password = ""
  @State var isLoading = false
  @State var signingUp = false
  @State var result: Result<Void, Error>?

  var body: some View {
    ZStack {
      VeoListView.color2.ignoresSafeArea() // Ensures background covers the whole screen
      VStack(spacing: 0) {
        Text("Veo - Sign " + (signingUp ? "up" : "in"))
          .font(.largeTitle)
          .fontWeight(.bold)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .padding(.vertical, 24)
          .background(VeoListView.color1)
        // Custom fields styled like VeoListView rows
        let extraRow = isLoading || (result != nil && !isLoading) ? 1 : 0
        let rowCount = 4 + extraRow
        VStack(spacing: 0) {
          HStack {
            TextField("Email", text: $email)
              .textContentType(.emailAddress)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .padding(.horizontal)
              .foregroundColor(.white)
              .font(.title2)
              .padding(.vertical, 0)
          }
          .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
          .padding(.horizontal, 0)
          .background(VeoListView.steppedGradientColor(for: 0, count: rowCount))
          HStack {
            SecureField("Password", text: $password)
              .textContentType(.password)
              .padding(.horizontal)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .foregroundColor(.white)
              .font(.title2)
              .padding(.vertical, 0)
          }
          .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
          .padding(.horizontal, 0)
          .background(VeoListView.steppedGradientColor(for: 1, count: rowCount))
          // Sign in/up button styled like a VeoListView row (no button background, whole row is tappable)
          HStack {
            Text("Sign " + (signingUp ? "up" : "in"))
              .font(.title2)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity, minHeight: 64)
          .background(VeoListView.steppedGradientColor(for: 2, count: rowCount))
          .contentShape(Rectangle())
          .onTapGesture {
            signInButtonTapped()
          }
          HStack {
            Text("Don't have an account? Sign " + (signingUp ? "in!" : "up!"))
              .font(.title2)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity, minHeight: 64)
          .background(VeoListView.steppedGradientColor(for: 3, count: rowCount))
          .contentShape(Rectangle())
          .onTapGesture {
            result = nil
            signingUp.toggle()
          }
          if isLoading {
            HStack {
              ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(VeoListView.steppedGradientColor(for: 4, count: rowCount))
          }
          if !isLoading, let result {
            switch result {
            case .success:
              HStack {
                Text("Signed " + (signingUp ? "up" : "in") + " successfully")
                  .font(.title2)
                  .foregroundColor(.green)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal)
                  .frame(maxWidth: .infinity, alignment: .center)
              }
              .frame(maxWidth: .infinity, minHeight: 64)
              .background(VeoListView.steppedGradientColor(for: 4, count: rowCount))
            case .failure(let error):
              HStack {
                Text(error.localizedDescription.prefix(1).capitalized + error.localizedDescription.dropFirst())
                  .font(.title2)
                  .foregroundColor(.red)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal)
              }
              .frame(maxWidth: .infinity, minHeight: 64)
              .background(VeoListView.steppedGradientColor(for: 4, count: rowCount))
            }
          }
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .top)
    }
  }

  func signInButtonTapped() {
    Task {
      isLoading = true
      defer { isLoading = false }

      do {
        if signingUp {
          try await supabase.auth.signUp(
            email: email,
            password: password
          )
        } else {
          try await supabase.auth.signIn(
              email: email,
              password: password
          )
        }
        result = .success(())
      } catch {
        result = .failure(error)
      }
    }
  }
}