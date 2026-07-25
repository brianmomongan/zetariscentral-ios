import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: SessionUser?
    @Published var isAuthenticated: Bool
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // If we already have a token from a previous launch, treat as signed in
        // and refresh the profile in the background.
        isAuthenticated = TokenStore.shared.token != nil
        if isAuthenticated {
            Task { await refreshMe() }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: LoginResponse = try await APIClient.shared.post(
                "/auth/login", body: ["email": email, "password": password], auth: false
            )
            TokenStore.shared.save(res.token)
            currentUser = res.user
            isAuthenticated = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Sign in failed."
        }
    }

    func logout() {
        TokenStore.shared.clear()
        currentUser = nil
        isAuthenticated = false
    }

    func refreshMe() async {
        do {
            struct MeResponse: Codable { let user: SessionUser }
            let res: MeResponse = try await APIClient.shared.get("/me")
            currentUser = res.user
        } catch APIError.unauthorized {
            logout()
        } catch {
            // Non-fatal; keep the cached auth state.
        }
    }
}
