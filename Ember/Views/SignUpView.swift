//
//  SignUpView.swift
//  Ember
//
//  Create a new account via /auth/register.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var error: String? = nil

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Text("Create your account")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let error = error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: submit) {
                    HStack {
                        if isLoading { ProgressView() }
                        Text("Create Account").bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || username.isEmpty || email.isEmpty || password.isEmpty)
                .padding(.horizontal)

                Button("Already have an account? Sign in") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .navigationTitle("Sign Up")
    }

    @MainActor
    private func submit() {
        error = nil
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await AuthAPI.register(username: username, email: email, password: password)
                // Optional: auto-login after successful registration
                _ = try await auth.login(email: email, password: password)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

