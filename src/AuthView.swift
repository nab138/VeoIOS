import SwiftUI

struct AuthView: View {
  @State var email = ""
  @State var password = ""
  @State var isLoading = false
  @State var result: Result<Void, Error>?

  var body: some View {
    ZStack {
      VeoListView.color2.ignoresSafeArea() // Ensures background covers the whole screen
      VStack(spacing: 0) {
        Text("Welcome to Veo")
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
          .background(Color.steppedGradientColor(for: 0, count: Double(rowCount)))
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
          .background(Color.steppedGradientColor(for: 1, count: Double(rowCount)))
          // Sign in/up button styled like a VeoListView row (no button background, whole row is tappable)
          HStack {
            Text("Sign in")
              .font(.title2)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity, minHeight: 64)
          .background(Color.steppedGradientColor(for: 2, count: Double(rowCount)))
          .contentShape(Rectangle())
          .onTapGesture {
            signInButtonTapped()
          }
          HStack {
            Text("Sign up")
              .font(.title2)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity, minHeight: 64)
          .background(Color.steppedGradientColor(for: 3, count: Double(rowCount)))
          .contentShape(Rectangle())
          .onTapGesture {
            signUpButtonTapped()
          }
          if isLoading {
            HStack {
              ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.steppedGradientColor(for: 4, count: Double(rowCount)))
          }
          if !isLoading, let result {
            switch result {
            case .success:
                Text("Success!")
            case .failure(let error):
              HStack {
                Text(error.localizedDescription.prefix(1).capitalized + error.localizedDescription.dropFirst())
                  .font(.title2)
                  .foregroundColor(.red)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal)
              }
              .frame(maxWidth: .infinity, minHeight: 64)
              .background(Color.steppedGradientColor(for: 4, count: Double(rowCount)))
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
        try await supabase.auth.signIn(
            email: email,
            password: password
        )
        result = .success(())
      } catch {
        result = .failure(error)
      }
    }
  }

  func signUpButtonTapped() {
    Task {
      isLoading = true
      defer { isLoading = false }

      do {
        try await supabase.auth.signUp(
          email: email,
          password: password
        )
        result = .success(())
      } catch {
        result = .failure(error)
      }
    }
  }
}