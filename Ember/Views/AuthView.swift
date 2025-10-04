//
//  AuthView.swift
//  Ember
//
//  Simple fake-login UI.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var error: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)
//            Text("Ember")
//                .font(.largeTitle).bold()
            Image("logo")
                .resizable()
                .scaledToFit() // or .scaledToFill()
                .frame(width: 200, height: 150)
            Text("Sign in to continue")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("Username", text: $username)
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
            .disabled(isLoading || username.isEmpty || password.isEmpty)
            .padding(.horizontal)

            Spacer()

            Text("Try demo/ember, alice/1234, or bob/password")
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.bottom, 12)
        }
    }

    private func submit() {
        error = nil
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isLoading = false
            if !auth.login(username: username, password: password) {
                error = "Invalid credentials"
            }
        }
    }
}

