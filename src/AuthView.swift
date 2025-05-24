import SwiftUI

struct AuthView: View {
  @State var email = ""
  @State var password = ""
  @State var isLoading = false
  @State var signingUp = false
  @State var result: Result<Void, Error>?

  var body: some View {
    VStack {
      Text("Veo - Sign " + (signingUp ? "up" : "in"))
        .font(.largeTitle)
        .padding(.top, 20)
      Text("Best list app ever")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.bottom, 20)
    }
    Form {
      Section {
        TextField("Email", text: $email)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        SecureField("Password", text: $password)
          .textContentType(.password)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }

      Section {
        Button("Sign in") {
          signInButtonTapped()
        }

        if isLoading {
          ProgressView()
        }
      }

      VStack {
        Spacer()
        Text("Don't have an account? Sign up")
          .font(.footnote)
          .foregroundStyle(.gray)
          .underline()
          .padding(.bottom, 16)
          .onTapGesture {
            signingUp.toggle()
          }
      }

      if let result {
        Section {
          switch result {
          case .success:
            Text("Signed " + (signingUp ? "up" : "in") + " successfully")
              .foregroundStyle(.green)
          case .failure(let error):
            Text(error.localizedDescription).foregroundStyle(.red)
          }
        }
      }
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