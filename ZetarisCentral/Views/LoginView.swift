import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.openURL) private var openURL
    @State private var email = ""
    @State private var password = ""
    @State private var registering = false
    @State private var ssoAvailable = false

    var body: some View {
        Group {
            if registering {
                RegisterView(onBack: { registering = false; auth.clearError() })
            } else {
                loginForm
            }
        }
        .task {
            if let c: AuthConfig = try? await APIClient.shared.get("/auth/config", auth: false) {
                ssoAvailable = c.microsoft
            }
        }
    }

    private var loginForm: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 6) {
                Lucide("send").font(.system(size: 44)).foregroundStyle(.tint)
                Text("Zetaris Central").font(.largeTitle.bold())
                Text("Sign in with your Zetaris account").font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = auth.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.login(email: email, password: password) }
            } label: {
                if auth.isLoading { ProgressView().frame(maxWidth: .infinity) }
                else { Text("Sign in").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

            if ssoAvailable {
                Button {
                    auth.clearError()
                    if let url = URL(string: "\(Config.origin)/api/auth/microsoft?mobile=1") { openURL(url) }
                } label: {
                    Label { Text("Sign in with Microsoft") } icon: { Lucide("building-2", size: 16) }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }

            Button("Don't have an account? Create one") { auth.clearError(); registering = true }
                .font(.footnote)

            Spacer()
        }
        .padding(24)
    }
}

private struct RegisterView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let onBack: () -> Void
    @State private var name = ""
    @State private var title = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 6) {
                Text("Create your account").font(.largeTitle.bold())
                Text("Join Zetaris Central").font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                field("Full name", text: $name)
                field("Job title (optional)", text: $title)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                SecureField("Password (min 8)", text: $password)
                    .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = auth.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.register(name: name, email: email, password: password, title: title) }
            } label: {
                if auth.isLoading { ProgressView().frame(maxWidth: .infinity) }
                else { Text("Create account").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(name.isEmpty || email.isEmpty || password.count < 8 || auth.isLoading)

            Button("Already have an account? Sign in", action: onBack).font(.footnote)
            Spacer()
        }
        .padding(24)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
