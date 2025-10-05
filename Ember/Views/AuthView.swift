//
//  AuthView.swift
//  Ember
//
//  Simple fake-login UI.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        VStack { // center content vertically
            Spacer()
            VStack(spacing: 18) {
                if UIImage(named: "logo") != nil {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 120)
                }
                Text("Sign in to continue")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let error = error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button(action: submit) {
                    HStack {
                        if isLoading { ProgressView().progressViewStyle(.circular) }
                        Text("Sign In").bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal)
            }
            Spacer()
        }
    }

    @MainActor
    private func submit() {
        error = nil
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                // Optional simulated delay
                try await Task.sleep(nanoseconds: 400_000_000)

                let ok = try await auth.login(email: email, password: password)
                if !ok {
                    error = "Invalid credentials"
                }
            } catch let e {
                self.error = e.localizedDescription
            }
        }
    }
}
